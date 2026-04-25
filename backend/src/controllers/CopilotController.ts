import { Request, Response } from "express";
import { CopilotService } from "../services/copilot/CopilotService.js";

export class CopilotController {
  constructor(private readonly service: CopilotService) {}

  dailyBrief = async (request: Request, response: Response) => {
    const userId = typeof request.query.userId === "string" ? request.query.userId : undefined;
    const payload = await this.service.getDailyBrief(userId);
    response.json(payload);
  };

  query = async (request: Request, response: Response) => {
    const payload = await this.service.query(request.body.userId, request.body.query);
    response.json(payload);
  };
}
