import { Router } from "express";
import { FuelController } from "../controllers/FuelController.js";
import { validateBody } from "../middleware/validate.js";
import { fuelSummaryRequestSchema } from "../domain/contracts/schemas.js";

export function createFuelRouter(controller: FuelController) {
  const router = Router();
  router.post("/summary", validateBody(fuelSummaryRequestSchema), controller.summarize);
  return router;
}
