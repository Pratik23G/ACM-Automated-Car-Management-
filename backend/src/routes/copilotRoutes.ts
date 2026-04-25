import { Router } from "express";
import { CopilotController } from "../controllers/CopilotController.js";
import { validateBody } from "../middleware/validate.js";
import { copilotQueryRequestSchema } from "../domain/contracts/schemas.js";

export function createCopilotRouter(controller: CopilotController) {
  const router = Router();
  router.get("/daily-brief", controller.dailyBrief);
  router.post("/query", validateBody(copilotQueryRequestSchema), controller.query);
  return router;
}
