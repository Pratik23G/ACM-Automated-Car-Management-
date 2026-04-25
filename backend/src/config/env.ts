import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  CORS_ORIGIN: z.string().default("*"),
  OPENAI_API_KEY: z.string().optional(),
  MODEL_BASE_URL: z.string().default("https://api.openai.com/v1"),
  MODEL_NAME: z.string().default("gpt-4.1-mini"),
  TINYFISH_API_KEY: z.string().optional(),
  TINYFISH_BASE_URL: z.string().default("https://api.tinyfish.example"),
  REDIS_URL: z.string().optional(),
  VAPI_API_KEY: z.string().optional(),
  VAPI_ORG_ID: z.string().optional(),
  VAPI_PUBLIC_KEY: z.string().optional(),
  VAPI_SQUAD_ID: z.string().optional(),
  VAPI_SQUAD_NAME: z.string().default("ACM Voice Copilot"),
  VAPI_BASE_URL: z.string().default("https://api.vapi.ai")
});

export const env = envSchema.parse(process.env);
