import { env } from "../config/env.js";
import { TinyfishFuelIntel, VehicleProfile } from "../domain/models/types.js";

export class TinyfishProvider {
  async getFuelIntel(profile: VehicleProfile): Promise<TinyfishFuelIntel> {
    const areaLabel = profile.homeArea || "your area";
    const baseline = profile.stationPreference === "cheapest" ? 4.12 : 4.29;

    // Replace this deterministic payload with the real Tinyfish integration.
    return {
      stations: [
        {
          name: "Costco",
          areaLabel,
          price: baseline,
          qualitySignal: "High traffic, strong value reputation",
          reputationScore: 0.82,
          promoSignal: "Warehouse membership savings"
        },
        {
          name: "Shell",
          areaLabel,
          price: baseline + 0.28,
          qualitySignal: "Top-tier additive reputation",
          reputationScore: 0.9,
          promoSignal: "Fuel rewards support"
        },
        {
          name: "Chevron",
          areaLabel,
          price: baseline + 0.19,
          qualitySignal: "Premium quality signal",
          reputationScore: 0.87,
          promoSignal: "App discount days"
        }
      ],
      news: [
        {
          headline: `Tinyfish outlook placeholder for ${areaLabel}`,
          summary: env.TINYFISH_API_KEY
            ? "Tinyfish provider is configured. Swap in the real fetch and normalization logic here."
            : "Tinyfish is not configured yet, so the backend is returning a deterministic development outlook.",
          direction: "steady"
        },
        {
          headline: "Local promo rotation",
          summary: "Reward-linked stations may outperform average street price when loyalty discounts stack.",
          direction: "down"
        }
      ]
    };
  }
}
