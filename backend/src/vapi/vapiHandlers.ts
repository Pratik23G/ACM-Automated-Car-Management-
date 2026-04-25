import redis from "../providers/redisClient.js";

type VapiToolCall = {
  message?: {
    toolCallList?: Array<{ id: string; function: { name: string; arguments: string } }>;
  };
};

function vapiResult(toolCallId: string, result: string) {
  return { results: [{ toolCallId, result }] };
}

export async function handleFuelVoice(body: VapiToolCall) {
  const call = body?.message?.toolCallList?.[0];
  const toolCallId = call?.id ?? "unknown";

  const raw = await redis.get("fuel:sf_zone:latest");
  if (!raw) return vapiResult(toolCallId, "No fuel data available right now. Try again shortly.");

  const fuel = JSON.parse(raw);
  const result = `Current average fuel price is $${fuel.avg_price_usd} per gallon. Cheapest nearby is ${fuel.cheapest_station_name ?? "a local station"} at $${fuel.cheapest_station_price} per gallon. Data is from ${fuel.timestamp}.`;
  return vapiResult(toolCallId, result);
}

export async function handleMaintenanceVoice(body: VapiToolCall) {
  const call = body?.message?.toolCallList?.[0];
  const toolCallId = call?.id ?? "unknown";

  const raw = await redis.get("weather:sf_default:latest");
  const weather = raw ? JSON.parse(raw) : null;
  const weatherNote = weather
    ? ` Current conditions: ${weather.condition ?? "unknown"}, ${weather.temp_c ?? "?"}°C.`
    : "";

  const result = `Maintenance estimate ready.${weatherNote} Please describe your vehicle and issue for a full recommendation.`;
  return vapiResult(toolCallId, result);
}

export async function handleCopilotVoice(body: VapiToolCall) {
  const call = body?.message?.toolCallList?.[0];
  const toolCallId = call?.id ?? "unknown";

  const [fuelRaw, weatherRaw] = await Promise.all([
    redis.get("fuel:sf_zone:latest"),
    redis.get("weather:sf_default:latest"),
  ]);

  const fuel = fuelRaw ? JSON.parse(fuelRaw) : null;
  const weather = weatherRaw ? JSON.parse(weatherRaw) : null;

  const parts: string[] = [];
  if (fuel) parts.push(`Fuel: $${fuel.avg_price_usd}/gal avg, cheapest $${fuel.cheapest_station_price} at ${fuel.cheapest_station_name ?? "nearby station"}`);
  if (weather) parts.push(`Weather: ${weather.condition ?? "unknown"}, ${weather.temp_c ?? "?"}°C, ${weather.precipitation_mm ?? 0}mm rain`);
  if (!parts.length) return vapiResult(toolCallId, "Live data not available yet. Pipelines may still be loading.");

  return vapiResult(toolCallId, parts.join(". ") + ".");
}