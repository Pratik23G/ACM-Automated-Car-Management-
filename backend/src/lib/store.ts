/**
 * Thin storage wrapper: uses Redis when REDIS_URL is set and reachable,
 * falls back to an in-memory Map for local dev without Redis installed.
 */
import { Redis } from 'ioredis'

let redisClient: Redis | null = null

if (process.env.REDIS_URL) {
  const client = new Redis(process.env.REDIS_URL, { lazyConnect: true, enableOfflineQueue: false })
  client.on('error', () => {}) // suppress unhandled error — we fall back to memory
  client.connect().catch(() => {}) // non-blocking
  redisClient = client
}

const memoryStore = new Map<string, { value: string; expiresAt: number }>()

export async function storeSet(key: string, value: string, ttlSeconds: number): Promise<void> {
  if (redisClient?.status === 'ready') {
    await redisClient.set(key, value, 'EX', ttlSeconds)
    return
  }
  memoryStore.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 })
}

export async function storeGet(key: string): Promise<string | null> {
  if (redisClient?.status === 'ready') {
    return redisClient.get(key)
  }
  const entry = memoryStore.get(key)
  if (!entry) return null
  if (Date.now() > entry.expiresAt) { memoryStore.delete(key); return null }
  return entry.value
}
