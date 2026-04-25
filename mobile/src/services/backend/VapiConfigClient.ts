import { VapiRuntimeConfig } from "../../models/agent";
import { BackendClient } from "./BackendClient";

export class VapiConfigClient {
  constructor(private readonly backend = new BackendClient()) {}

  async getConfig(): Promise<VapiRuntimeConfig> {
    return this.backend.get<VapiRuntimeConfig>("/vapi/config");
  }
}
