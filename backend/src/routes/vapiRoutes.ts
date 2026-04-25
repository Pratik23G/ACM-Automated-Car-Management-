import { Router } from "express";
import { VapiController } from "../controllers/VapiController.js";

export function createVapiRouter(controller: VapiController) {
  const router = Router();
  router.get("/config", controller.config);
  return router;
}
