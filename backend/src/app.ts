import cors from "cors";
import express from "express";
import { env } from "./config/env.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { TinyfishProvider } from "./providers/TinyfishProvider.js";
import { RedisMemoryProvider } from "./providers/RedisMemoryProvider.js";
import { ModelProvider } from "./providers/ModelProvider.js";
import { VapiProvider } from "./providers/VapiProvider.js";
import { FuelAgentService } from "./services/fuel/FuelAgentService.js";
import { MaintenanceAgentService } from "./services/maintenance/MaintenanceAgentService.js";
import { CopilotService } from "./services/copilot/CopilotService.js";
import { VoiceSummaryService } from "./services/voice/VoiceSummaryService.js";
import { FuelController } from "./controllers/FuelController.js";
import { MaintenanceController } from "./controllers/MaintenanceController.js";
import { CopilotController } from "./controllers/CopilotController.js";
import { VoiceController } from "./controllers/VoiceController.js";
import { VapiController } from "./controllers/VapiController.js";
import { createFuelRouter } from "./routes/fuelRoutes.js";
import { createMaintenanceRouter } from "./routes/maintenanceRoutes.js";
import { createCopilotRouter } from "./routes/copilotRoutes.js";
import { createVoiceRouter } from "./routes/voiceRoutes.js";
import { createVapiRouter } from "./routes/vapiRoutes.js";

const app = express();

const memory = new RedisMemoryProvider(env.REDIS_URL);
const tinyfish = new TinyfishProvider();
const model = new ModelProvider(env.OPENAI_API_KEY, env.MODEL_NAME);
const vapi = new VapiProvider({
  apiKey: env.VAPI_API_KEY,
  baseUrl: env.VAPI_BASE_URL,
  orgId: env.VAPI_ORG_ID,
  publicKey: env.VAPI_PUBLIC_KEY,
  squadId: env.VAPI_SQUAD_ID,
  squadName: env.VAPI_SQUAD_NAME
});

const fuelController = new FuelController(new FuelAgentService(tinyfish, model, memory));
const maintenanceController = new MaintenanceController(new MaintenanceAgentService(model, memory));
const copilotController = new CopilotController(new CopilotService(memory, model));
const voiceController = new VoiceController(new VoiceSummaryService(memory, vapi));
const vapiController = new VapiController(vapi);

app.use(cors({ origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN }));
app.use(express.json());

app.get("/health", (_request, response) => {
  response.json({
    ok: true,
    service: "acm2-backend"
  });
});

app.use("/fuel", createFuelRouter(fuelController));
app.use("/maintenance", createMaintenanceRouter(maintenanceController));
app.use("/copilot", createCopilotRouter(copilotController));
app.use("/voice", createVoiceRouter(voiceController));
app.use("/vapi", createVapiRouter(vapiController));

app.use(errorHandler);

export { app };
