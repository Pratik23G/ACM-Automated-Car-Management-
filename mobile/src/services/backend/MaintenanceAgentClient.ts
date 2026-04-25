import { MaintenanceAnalyzeRequest, MaintenanceAnalyzeResponse } from "./contracts";
import { BackendClient } from "./BackendClient";

export class MaintenanceAgentClient {
  constructor(private readonly backend = new BackendClient()) {}

  analyze(request: MaintenanceAnalyzeRequest): Promise<MaintenanceAnalyzeResponse> {
    return this.backend.post<MaintenanceAnalyzeResponse>("/maintenance/analyze", request);
  }
}
