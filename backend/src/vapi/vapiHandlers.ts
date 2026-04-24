import { sendToVapi } from "./vapiClient";
import { maintenancePrompt } from "./prompts/maintenancePrompt";
import { fuelPrompt } from "./prompts/fuelPrompt";
import { copilotPrompt } from "./prompts/copilotPrompt";

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