import { createClient, RedisClientType } from "redis";
import { logger } from "../config/logger.js";

export class RedisMemoryProvider {
  private readonly fallback = new Map<string, string>();
  private client: RedisClientType | null = null;
  private connected = false;

  constructor(private readonly redisUrl?: string) {}

  async getJson<T>(key: string): Promise<T | null> {
    const raw = await this.get(key);
    return raw ? (JSON.parse(raw) as T) : null;
  }

  async setJson(key: string, value: unknown, ttlSeconds = 900): Promise<void> {
    const serialized = JSON.stringify(value);
    await this.set(key, serialized, ttlSeconds);
  }

  async rememberSnapshot(userId: string, label: string, value: unknown): Promise<void> {
    await this.setJson(`snapshot:${userId}:${label}`, value, 60 * 60);
    await this.setJson("snapshot:last-user", { userId }, 60 * 60);
  }

  async latestUserId(): Promise<string | null> {
    const snapshot = await this.getJson<{ userId: string }>("snapshot:last-user");
    return snapshot?.userId ?? null;
  }

  private async get(key: string): Promise<string | null> {
    const client = await this.ensureClient();
    if (!client) {
      return this.fallback.get(key) ?? null;
    }
    return client.get(key);
  }

  private async set(key: string, value: string, ttlSeconds: number) {
    const client = await this.ensureClient();
    if (!client) {
      this.fallback.set(key, value);
      return;
    }
    await client.set(key, value, { EX: ttlSeconds });
  }

  private async ensureClient(): Promise<RedisClientType | null> {
    if (!this.redisUrl) {
      return null;
    }

    if (!this.client) {
      this.client = createClient({ url: this.redisUrl });
      this.client.on("error", (error) => logger.warn("Redis client error, falling back to memory.", error));
    }

    if (!this.connected) {
      try {
        await this.client.connect();
        this.connected = true;
      } catch (error) {
        logger.warn("Could not connect to Redis. Using in-memory fallback.", error);
        return null;
      }
    }

    return this.client;
  }
}
