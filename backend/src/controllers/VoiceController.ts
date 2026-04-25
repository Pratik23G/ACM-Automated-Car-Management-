import { Request, Response } from "express";
import { VoiceSummaryService } from "../services/voice/VoiceSummaryService.js";

export class VoiceController {
  constructor(private readonly service: VoiceSummaryService) {}

  summarize = async (request: Request, response: Response) => {
    const payload = await this.service.summarize(request.body);
    response.json(payload);
  };
}
