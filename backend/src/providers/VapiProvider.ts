import { VapiRuntimeConfig, VoiceSummaryResponse } from "../domain/models/types.js";
import { makeId } from "../utils/id.js";
import { logger } from "../config/logger.js";

interface VapiSquadSummary {
  id?: string;
  name?: string;
  orgId?: string;
}

export class VapiProvider {
  private cachedSquad?: { id?: string; name?: string };

  constructor(
    private readonly options: {
      apiKey?: string;
      baseUrl: string;
      orgId?: string;
      publicKey?: string;
      squadId?: string;
      squadName?: string;
    }
  ) {}

  async getRuntimeConfig(): Promise<VapiRuntimeConfig> {
    if (!this.options.apiKey) {
      return {
        backendReady: false,
        webSdkReady: false,
        message: "Add VAPI_API_KEY on the backend to enable squad discovery and voice handoff."
      };
    }

    const squad = await this.resolveSquad();
    const publicKey = this.options.publicKey?.trim() || undefined;
    const webSdkReady = Boolean(publicKey && squad.id);

    return {
      backendReady: true,
      webSdkReady,
      squadId: squad.id,
      squadName: squad.name ?? this.options.squadName,
      publicKey,
      message: squad.id
        ? webSdkReady
          ? `Live Vapi voice is ready for ${squad.name ?? "your ACM squad"}.`
          : `Vapi backend is connected to ${squad.name ?? "your ACM squad"}. Add VAPI_PUBLIC_KEY to enable live browser voice.`
        : "Vapi backend is authenticated, but no ACM squad was resolved yet. Set VAPI_SQUAD_ID or verify the ACM Voice Copilot squad exists in Vapi."
    };
  }

  async createVoiceSummary(input: {
    context: string;
    transcript: string;
    fuelHeadline?: string;
    maintenanceHeadline?: string;
  }): Promise<VoiceSummaryResponse> {
    const runtime = await this.getRuntimeConfig();

    return {
      summary: runtime.backendReady
        ? `Vapi backend is connected for ${input.context}. ${runtime.webSdkReady ? "You can start a live browser voice session from the Copilot screen." : "Live browser voice still needs a Vapi public key."}`
        : `Voice summary scaffold for ${input.context}: ${input.transcript}`,
      cards: [
        {
          id: makeId("voice-card"),
          type: "summary",
          title: "Voice Copilot Summary",
          body: `Fuel context: ${input.fuelHeadline ?? "none"}. Maintenance context: ${input.maintenanceHeadline ?? "none"}. ${runtime.squadName ? `Squad: ${runtime.squadName}.` : ""}`.trim(),
          tone: "info"
        }
      ],
      action: {
        id: makeId("voice-action"),
        type: "voice",
        title: runtime.webSdkReady ? "Start live Vapi voice" : "Finish Vapi setup",
        description: runtime.message,
        priority: "medium",
        destination: "copilot"
      }
    };
  }

  private async resolveSquad(): Promise<{ id?: string; name?: string }> {
    if (this.cachedSquad) {
      return this.cachedSquad;
    }

    if (this.options.squadId) {
      this.cachedSquad = {
        id: this.options.squadId,
        name: this.options.squadName
      };
      return this.cachedSquad;
    }

    try {
      const response = await fetch(`${this.options.baseUrl.replace(/\/$/, "")}/squad`, {
        headers: {
          Authorization: `Bearer ${this.options.apiKey}`,
          Accept: "application/json"
        }
      });

      if (!response.ok) {
        logger.warn("Vapi squad lookup failed", { status: response.status });
        return {};
      }

      const squads = (await response.json()) as VapiSquadSummary[];
      const filteredByOrg = this.options.orgId ? squads.filter((squad) => squad.orgId === this.options.orgId) : squads;
      const preferredName = this.options.squadName?.trim().toLowerCase();

      const exactMatch = preferredName
        ? filteredByOrg.find((squad) => squad.name?.trim().toLowerCase() === preferredName)
        : undefined;
      const resolved = exactMatch ?? (filteredByOrg.length === 1 ? filteredByOrg[0] : undefined);

      this.cachedSquad = resolved
        ? {
            id: resolved.id,
            name: resolved.name
          }
        : {};

      return this.cachedSquad;
    } catch (error) {
      logger.warn("Vapi squad lookup threw an error", error);
      return {};
    }
  }
}
