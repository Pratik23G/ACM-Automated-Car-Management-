import { Router } from "express";
import { VoiceController } from "../controllers/VoiceController.js";
import { validateBody } from "../middleware/validate.js";
import { voiceSummaryRequestSchema } from "../domain/contracts/schemas.js";

export function createVoiceRouter(controller: VoiceController) {
  const router = Router();
  router.post("/summary", validateBody(voiceSummaryRequestSchema), controller.summarize);
  return router;
}
