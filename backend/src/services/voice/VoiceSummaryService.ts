import { RedisMemoryProvider } from "../../providers/RedisMemoryProvider.js";
import { VapiProvider } from "../../providers/VapiProvider.js";
import { FuelSummary, MaintenanceAnalysis, VoiceSummaryResponse } from "../../domain/models/types.js";

export class VoiceSummaryService {
  constructor(private readonly memory: RedisMemoryProvider, private readonly vapi: VapiProvider) {}

  async summarize(input: {
    userId: string;
    context: "fuel" | "maintenance" | "copilot";
    transcript: string;
  }): Promise<VoiceSummaryResponse> {
    const fuel = await this.memory.getJson<FuelSummary>(`snapshot:${input.userId}:fuel`);
    const maintenance = await this.memory.getJson<MaintenanceAnalysis>(`snapshot:${input.userId}:maintenance`);

    return this.vapi.createVoiceSummary({
      context: input.context,
      transcript: input.transcript,
      fuelHeadline: fuel?.newsHeadline,
      maintenanceHeadline: maintenance?.cards[0]?.title
    });
  }
}
