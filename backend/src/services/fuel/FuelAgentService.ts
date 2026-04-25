import { RedisMemoryProvider } from "../../providers/RedisMemoryProvider.js";
import { ModelProvider } from "../../providers/ModelProvider.js";
import { TinyfishProvider } from "../../providers/TinyfishProvider.js";
import { FuelSummary, FuelStationSummary, VehicleProfile, CopilotCard, AgentAction, TinyfishFuelIntel } from "../../domain/models/types.js";
import { average, roundCurrency } from "../../utils/math.js";
import { makeId } from "../../utils/id.js";

interface FuelSummaryRequest {
  userId: string;
  profile: VehicleProfile;
}

export class FuelAgentService {
  constructor(
    private readonly tinyfish: TinyfishProvider,
    private readonly model: ModelProvider,
    private readonly memory: RedisMemoryProvider
  ) {}

  async summarize(input: FuelSummaryRequest & { trips: unknown[]; fuelLogs: unknown[] }): Promise<FuelSummary> {
    const cacheKey = `fuel:${input.userId}:${input.profile.homeArea ?? "default"}:${input.profile.preferredFuelProduct}`;
    const cached = await this.memory.getJson<FuelSummary>(cacheKey);
    if (cached) {
      return cached;
    }

    const intel = await this.tinyfish.getFuelIntel(input.profile);
    const averagePrice = roundCurrency(average(intel.stations.map((station) => station.price)));
    const cheapest = [...intel.stations].sort((left, right) => left.price - right.price)[0];
    const premium = [...intel.stations].sort((left, right) => right.reputationScore - left.reputationScore)[0];
    const weeklyUnits = this.weeklyEnergyUnits(input.profile);
    const weeklyCost = roundCurrency(weeklyUnits * averagePrice);
    const monthlyCost = roundCurrency(weeklyCost * 4.33);
    const yearlyCost = roundCurrency(weeklyCost * 52);
    const estimatedSavings = roundCurrency(Math.max(0, (averagePrice - cheapest.price) * weeklyUnits));
    const newsHeadline = intel.news[0]?.headline ?? "Fuel market steady";

    const ai = await this.model.buildFuelNarrative({
      profile: input.profile,
      weeklyCost,
      monthlyCost,
      yearlyCost,
      newsHeadline,
      cheapestStationName: cheapest.name
    });

    const response: FuelSummary = {
      areaLabel: input.profile.homeArea ?? "your area",
      fuelProduct: input.profile.preferredFuelProduct,
      localAveragePrice: averagePrice,
      cheapestStation: this.toStationSummary(cheapest, "Best immediate value from the current normalized feed."),
      premiumStation: this.toStationSummary(
        premium,
        "Strong reputation signal for drivers who want higher confidence on quality."
      ),
      weeklyCost,
      monthlyCost,
      yearlyCost,
      estimatedSavings,
      newsHeadline,
      cards: [...this.buildSystemCards(intel, averagePrice, weeklyCost, monthlyCost), ...ai.cards],
      actions: this.buildActions(intel, estimatedSavings)
    };

    await this.memory.setJson(cacheKey, response, 300);
    await this.memory.rememberSnapshot(input.userId, "fuel", response);
    await this.memory.rememberSnapshot(input.userId, "profile", input.profile);
    await this.memory.rememberSnapshot(input.userId, "trips", input.trips);
    return response;
  }

  private weeklyEnergyUnits(profile: VehicleProfile) {
    if (profile.fuelType === "electric") {
      return profile.weeklyMiles / Math.max(profile.miPerKwh ?? 3.2, 1);
    }
    return profile.weeklyMiles / Math.max(profile.mpg ?? 25, 1);
  }

  private toStationSummary(station: TinyfishFuelIntel["stations"][number], savingsNote: string): FuelStationSummary {
    return {
      name: station.name,
      areaLabel: station.areaLabel,
      price: roundCurrency(station.price),
      qualitySignal: station.qualitySignal,
      savingsNote
    };
  }

  private buildSystemCards(
    intel: TinyfishFuelIntel,
    averagePrice: number,
    weeklyCost: number,
    monthlyCost: number
  ): CopilotCard[] {
    return [
      {
        id: makeId("fuel-hero"),
        type: "hero",
        title: "Fuel Agent Snapshot",
        body: "This card comes from the backend and is ready to absorb real Tinyfish prices, station quality signals, and price-moving news.",
        tone: "info",
        items: [
          { label: "Local average", value: `$${averagePrice.toFixed(2)}` },
          { label: "Weekly cost", value: `$${weeklyCost.toFixed(2)}` },
          { label: "Monthly cost", value: `$${monthlyCost.toFixed(2)}` }
        ]
      },
      {
        id: makeId("fuel-news"),
        type: "summary",
        title: intel.news[0]?.headline ?? "Fuel market pulse",
        body: intel.news[0]?.summary ?? "No Tinyfish news signal is wired yet.",
        tone: intel.news[0]?.direction === "up" ? "warning" : "info",
        tags: intel.news.map((item) => item.direction)
      }
    ];
  }

  private buildActions(intel: TinyfishFuelIntel, estimatedSavings: number): AgentAction[] {
    const newsDirection = intel.news[0]?.direction ?? "steady";
    const actions: AgentAction[] = [];

    if (newsDirection === "up") {
      actions.push({
        id: makeId("fuel-alert"),
        type: "notification",
        title: "Price rise watch",
        description: "Backend recommends a gas-price alert because the normalized market direction is trending upward.",
        priority: "high",
        destination: "fuel"
      });
    }

    if (estimatedSavings >= 4) {
      actions.push({
        id: makeId("fuel-savings"),
        type: "recommendation",
        title: "Switch station strategy",
        description: `Potential weekly savings of $${estimatedSavings.toFixed(2)} justify nudging the user toward the cheapest reliable station.`,
        priority: "medium",
        destination: "fuel"
      });
    }

    return actions;
  }
}
