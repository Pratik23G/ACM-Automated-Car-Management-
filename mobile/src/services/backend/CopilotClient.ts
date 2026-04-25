import { CopilotQueryApiResponse, CopilotQueryRequest, DailyBriefResponse } from "./contracts";
import { BackendClient } from "./BackendClient";

export class CopilotClient {
  constructor(private readonly backend = new BackendClient()) {}

  getDailyBrief(): Promise<DailyBriefResponse> {
    return this.backend.get<DailyBriefResponse>("/copilot/daily-brief");
  }

  query(request: CopilotQueryRequest): Promise<CopilotQueryApiResponse> {
    return this.backend.post<CopilotQueryApiResponse>("/copilot/query", request);
  }
}
