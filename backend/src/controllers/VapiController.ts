import { Request, Response } from "express";
import { VapiProvider } from "../providers/VapiProvider.js";

export class VapiController {
  constructor(private readonly provider: VapiProvider) {}

  config = async (_request: Request, response: Response) => {
    const payload = await this.provider.getRuntimeConfig();
    response.json(payload);
  };
}
