import { RedisMemoryProvider } from "../../providers/RedisMemoryProvider.js";
import { ModelProvider } from "../../providers/ModelProvider.js";
import { CopilotQueryResponse, DailyBrief, FuelSummary, MaintenanceAnalysis, TripResult, VehicleProfile } from "../../domain/models/types.js";
import { makeId } from "../../utils/id.js";

export class CopilotService {
  constructor(private readonly memory: RedisMemoryProvider, private readonly model: ModelProvider) {}

  async getDailyBrief(userId?: string): Promise<DailyBrief> {
    const resolvedUserId = userId ?? (await this.memory.latestUserId()) ?? "demo-user";
    const fuel = await this.memory.getJson<FuelSummary>(`snapshot:${resolvedUserId}:fuel`);
    const maintenance = await this.memory.getJson<MaintenanceAnalysis>(`snapshot:${resolvedUserId}:maintenance`);

    return {
      headline: this.makeHeadline(fuel, maintenance),
      cards: [
        ...(fuel?.cards.slice(0, 1) ?? [
          {
            id: makeId("copilot-fuel-placeholder"),
            type: "summary",
            title: "Fuel context missing",
            body: "Daily brief is waiting for a recent /fuel/summary call.",
            tone: "warning"
          }
        ]),
        ...(maintenance?.cards.slice(0, 1) ?? [
          {
            id: makeId("copilot-maint-placeholder"),
            type: "summary",
            title: "Maintenance context missing",
            body: "Daily brief is waiting for a recent /maintenance/analyze call.",
            tone: "warning"
          }
        ])
      ],
      actions: [...(fuel?.actions ?? []).slice(0, 1), ...(maintenance?.actions ?? []).slice(0, 1)]
    };
  }

  async query(userId: string, query: string): Promise<CopilotQueryResponse> {
    const fuel = await this.memory.getJson<FuelSummary>(`snapshot:${userId}:fuel`);
    const maintenance = await this.memory.getJson<MaintenanceAnalysis>(`snapshot:${userId}:maintenance`);
    const profile = await this.memory.getJson<VehicleProfile>(`snapshot:${userId}:profile`);
    const trips = await this.memory.getJson<TripResult[]>(`snapshot:${userId}:trips`);

    return this.model.answerCopilotQuery({
      query,
      profile,
      latestFuelHeadline: fuel?.newsHeadline,
      latestMaintenanceHeadline: maintenance?.cards[0]?.title,
      recentTrips: trips ?? undefined
    });
  }

  private makeHeadline(fuel?: FuelSummary | null, maintenance?: MaintenanceAnalysis | null) {
    if (fuel && maintenance) {
      return `Fuel outlook says “${fuel.newsHeadline}” while maintenance still has ${maintenance.estimates.filter((estimate) => estimate.severity !== "ok").length} items worth watching.`;
    }
    if (fuel) {
      return `Fuel outlook is ready, but the maintenance agent has not been refreshed yet.`;
    }
    if (maintenance) {
      return `Maintenance context is ready, but fuel intel has not been refreshed yet.`;
    }
    return "Run the fuel and maintenance agents once so the daily brief has real context to merge.";
  }
}
