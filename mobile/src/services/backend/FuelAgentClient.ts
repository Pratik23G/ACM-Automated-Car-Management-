import { FuelSummaryResponse, FuelSummaryRequest } from "./contracts";
import { BackendClient } from "./BackendClient";

export class FuelAgentClient {
  constructor(private readonly backend = new BackendClient()) {}

  getSummary(request: FuelSummaryRequest): Promise<FuelSummaryResponse> {
    return this.backend.post<FuelSummaryResponse>("/fuel/summary", request);
  }
}
