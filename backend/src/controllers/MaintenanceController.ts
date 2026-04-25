import { Request, Response } from "express";
import { MaintenanceAgentService } from "../services/maintenance/MaintenanceAgentService.js";

export class MaintenanceController {
  constructor(private readonly service: MaintenanceAgentService) {}

  analyze = async (request: Request, response: Response) => {
    const payload = await this.service.analyze(request.body);
    response.json(payload);
  };
}
