import { FastifyInstance } from "fastify";
import {
  handleMaintenanceVoice,
  handleFuelVoice,
  handleCopilotVoice,
} from "./vapiHandlers";

export async function vapiRoutes(app: FastifyInstance) {
  
  app.post("/vapi/maintenance", async (req, res) => {
    const result = await handleMaintenanceVoice(req.body);
    return result;
  });

  app.post("/vapi/fuel", async (req, res) => {
    const result = await handleFuelVoice(req.body);
    return result;
  });

  app.post("/vapi/copilot", async (req, res) => {
    const result = await handleCopilotVoice(req.body);
    return result;
  });

}