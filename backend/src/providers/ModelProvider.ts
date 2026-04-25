import { CopilotCard, CopilotQueryResponse, MaintenanceAnalysis, MaintenanceEstimate, TripResult, VehicleProfile } from "../domain/models/types.js";
import { makeId } from "../utils/id.js";

export class ModelProvider {
  constructor(private readonly apiKey?: string, private readonly modelName?: string) {}

  async buildFuelNarrative(input: {
    profile: VehicleProfile;
    weeklyCost: number;
    monthlyCost: number;
    yearlyCost: number;
    newsHeadline: string;
    cheapestStationName: string;
  }): Promise<{ summary: string; cards: CopilotCard[] }> {
    const summary = this.apiKey
      ? `Model ${this.modelName ?? "default"} is configured. Replace this placeholder with the real prompt + completion call.`
      : `Fuel costs are being driven more by station selection and route cadence than by dramatic market movement right now.`;

    return {
      summary,
      cards: [
        {
          id: makeId("fuel-llm"),
          type: "summary",
          title: "AI Fuel Recommendation",
          body: `${summary} Weekly estimate: $${input.weeklyCost.toFixed(2)}, monthly estimate: $${input.monthlyCost.toFixed(2)}, yearly estimate: $${input.yearlyCost.toFixed(2)}.`,
          tone: "info",
          tags: [input.newsHeadline, input.cheapestStationName]
        }
      ]
    };
  }

  async buildMaintenanceNarrative(input: {
    profile: VehicleProfile;
    estimates: MaintenanceEstimate[];
  }): Promise<Pick<MaintenanceAnalysis, "cards" | "actions">> {
    const risky = input.estimates.filter((estimate) => estimate.severity !== "ok");

    return {
      cards: [
        {
          id: makeId("maint-llm"),
          type: "summary",
          title: "AI Maintenance Explanation",
          body: risky.length
            ? `Driving behavior is shortening ${risky.map((estimate) => estimate.serviceType).join(", ")} more than your default schedule would suggest.`
            : "No urgent maintenance compression showed up in the current analysis.",
          tone: risky.length ? "warning" : "success"
        }
      ],
      actions: risky.length
        ? [
            {
              id: makeId("maint-action"),
              type: "notification",
              title: "Review near-term service items",
              description: "The backend recommends surfacing the highest-risk maintenance estimates as user-facing alerts.",
              priority: "high",
              destination: "maintenance"
            }
          ]
        : []
    };
  }

  async answerCopilotQuery(input: {
    query: string;
    profile?: VehicleProfile | null;
    latestFuelHeadline?: string;
    latestMaintenanceHeadline?: string;
    recentTrips?: TripResult[];
  }): Promise<CopilotQueryResponse> {
    const routePressure = input.recentTrips?.length ? "recent drive history" : "limited drive history";

    return {
      answer: `For “${input.query}”, the copilot would combine fuel, maintenance, and ${routePressure} context before answering. This is the backend seam where the real model call should go.`,
      cards: [
        {
          id: makeId("copilot-answer"),
          type: "summary",
          title: "Copilot Reasoning Scaffold",
          body: `Fuel context: ${input.latestFuelHeadline ?? "none cached yet"}. Maintenance context: ${input.latestMaintenanceHeadline ?? "none cached yet"}.`,
          tone: "info"
        }
      ],
      actions: []
    };
  }
}
