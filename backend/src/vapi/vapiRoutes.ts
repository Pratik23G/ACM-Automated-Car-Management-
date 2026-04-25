import { FastifyInstance } from "fastify";
import {
  handleMaintenanceVoice,
  handleFuelVoice,
  handleCopilotVoice,
} from "./vapiHandlers.js";

export async function vapiRoutes(app: FastifyInstance) {
  
  app.post("/vapi/maintenance", async (req, res) => {
    const result = await handleMaintenanceVoice(req.body as any);
    return result;
  });

  app.post("/vapi/fuel", async (req, res) => {
    const result = await handleFuelVoice(req.body as any);
    return result;
  });

  app.post("/vapi/copilot", async (req, res) => {
    const result = await handleCopilotVoice(req.body as any);
    return result;
  });

}