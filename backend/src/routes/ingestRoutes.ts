import { Router } from "express";
import { createClient } from "redis";
import { env } from "../config/env.js";

const FUEL_KEY = "fuel:sf_zone:latest";
const WEATHER_KEY = "weather:sf_default:latest";
const FUEL_TTL = 93600;
const WEATHER_TTL = 7200;

let redisClient: ReturnType<typeof createClient> | null = null;

async function getRedis() {
  if (!env.REDIS_URL) return null;
  if (!redisClient) {
    redisClient = createClient({ url: env.REDIS_URL });
    redisClient.on("error", () => {});
    await redisClient.connect().catch(() => { redisClient = null; });
  }
  return redisClient;
}

export function createIngestRouter() {
  const router = Router();

  router.post("/weather/ingest", async (req, res) => {
    const body = req.body;
    if (!body) { res.status(400).json({ error: "Missing body" }); return; }
    const client = await getRedis();
    if (client) await client.set(WEATHER_KEY, JSON.stringify(body), { EX: WEATHER_TTL });
    res.json({ ok: true, key: WEATHER_KEY });
  });

  router.get("/weather/current", async (_req, res) => {
    const client = await getRedis();
    const data = client ? await client.get(WEATHER_KEY) : null;
    if (!data) { res.status(404).json({ error: "No weather snapshot found." }); return; }
    res.json(JSON.parse(data));
  });

  router.post("/fuel/ingest", async (req, res) => {
    const body = req.body;
    if (!body) { res.status(400).json({ error: "Missing body" }); return; }
    const client = await getRedis();
    if (client) await client.set(FUEL_KEY, JSON.stringify(body), { EX: FUEL_TTL });
    res.json({ ok: true, key: FUEL_KEY });
  });

  router.get("/fuel/current", async (_req, res) => {
    const client = await getRedis();
    const data = client ? await client.get(FUEL_KEY) : null;
    if (!data) { res.status(404).json({ error: "No fuel snapshot found." }); return; }
    res.json(JSON.parse(data));
  });

  return router;
}
