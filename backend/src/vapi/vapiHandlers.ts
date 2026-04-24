import { sendToVapi } from "./vapiClient.js";
import { maintenancePrompt } from "./prompts/maintenancePrompt.js";
import { fuelPrompt } from "./prompts/fuelPrompt.js";
import { copilotPrompt } from "./prompts/copilotPrompt.js";

export async function handleMaintenanceVoice(data: any) {
  const prompt = maintenancePrompt(data);

  return sendToVapi({
    model: "gpt-4o-mini",
    voice: "alloy",
    input: prompt,
  });
}

export async function handleFuelVoice(data: any) {
  const prompt = fuelPrompt(data);

  return sendToVapi({
    model: "gpt-4o-mini",
    voice: "alloy",
    input: prompt,
  });
}

export async function handleCopilotVoice(data: any) {
  const prompt = copilotPrompt(data);

  return sendToVapi({
    model: "gpt-4o-mini",
    voice: "alloy",
    input: prompt,
  });
}