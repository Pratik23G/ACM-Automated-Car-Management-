import { Request, Response } from "express";
import { FuelAgentService } from "../services/fuel/FuelAgentService.js";

export class FuelController {
  constructor(private readonly service: FuelAgentService) {}

  summarize = async (request: Request, response: Response) => {
    const payload = await this.service.summarize(request.body);
    response.json(payload);
  };
}
