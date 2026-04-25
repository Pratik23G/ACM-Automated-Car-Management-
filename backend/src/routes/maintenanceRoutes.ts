import { Router } from "express";
import { MaintenanceController } from "../controllers/MaintenanceController.js";
import { validateBody } from "../middleware/validate.js";
import { maintenanceAnalyzeRequestSchema } from "../domain/contracts/schemas.js";

export function createMaintenanceRouter(controller: MaintenanceController) {
  const router = Router();
  router.post("/analyze", validateBody(maintenanceAnalyzeRequestSchema), controller.analyze);
  return router;
}
