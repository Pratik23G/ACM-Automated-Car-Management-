import { VoiceSummaryApiResponse, VoiceSummaryRequest } from "./contracts";
import { BackendClient } from "./BackendClient";

export class VoiceAgentClient {
  constructor(private readonly backend = new BackendClient()) {}

  summarize(request: VoiceSummaryRequest): Promise<VoiceSummaryApiResponse> {
    return this.backend.post<VoiceSummaryApiResponse>("/voice/summary", request);
  }
}
