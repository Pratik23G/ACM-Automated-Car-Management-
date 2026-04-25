import { Platform } from "react-native";
import { VapiRuntimeConfig } from "../../models/agent";

interface VapiLikeClient {
  start(config: { squadId: string }): Promise<void> | void;
  stop(): Promise<void> | void;
  on(event: string, handler: (...args: any[]) => void): void;
  off?(event: string, handler: (...args: any[]) => void): void;
}

interface VapiEventHandlers {
  onCallStart?: () => void;
  onCallEnd?: () => void;
  onStatus?: (status: string) => void;
  onTranscript?: (transcript: string) => void;
  onError?: (message: string) => void;
}

export class VapiWebClient {
  private client?: VapiLikeClient;
  private listeners: Array<{ event: string; handler: (...args: any[]) => void }> = [];

  async start(config: VapiRuntimeConfig, handlers: VapiEventHandlers = {}) {
    if (Platform.OS !== "web") {
      throw new Error("Live Vapi voice is currently wired for Expo Web. Native apps can keep using the backend voice summary flow.");
    }

    if (!config.publicKey || !config.squadId) {
      throw new Error("Vapi is missing a public key or squad ID.");
    }

    const module = await import("@vapi-ai/web");
    const Vapi = module.default;

    if (!this.client) {
      this.client = new Vapi(config.publicKey) as unknown as VapiLikeClient;
    }

    this.clearListeners();

    this.bind("call-start", () => {
      handlers.onStatus?.("Live voice connected.");
      handlers.onCallStart?.();
    });
    this.bind("call-end", () => {
      handlers.onStatus?.("Live voice stopped.");
      handlers.onCallEnd?.();
    });
    this.bind("error", (error: unknown) => {
      handlers.onError?.(this.formatError(error));
    });
    this.bind("message", (message: any) => {
      if (message?.type === "transcript" && typeof message.transcript === "string") {
        const speaker = typeof message.role === "string" ? message.role : "assistant";
        handlers.onTranscript?.(`${speaker}: ${message.transcript}`);
      }
    });

    await this.client.start({ squadId: config.squadId });
  }

  async stop() {
    await this.client?.stop();
    this.clearListeners();
  }

  private bind(event: string, handler: (...args: any[]) => void) {
    this.client?.on(event, handler);
    this.listeners.push({ event, handler });
  }

  private clearListeners() {
    for (const listener of this.listeners) {
      this.client?.off?.(listener.event, listener.handler);
    }
    this.listeners = [];
  }

  private formatError(error: unknown) {
    if (error instanceof Error) {
      return error.message;
    }

    if (typeof error === "string") {
      return error;
    }

    return "Vapi call failed.";
  }
}
