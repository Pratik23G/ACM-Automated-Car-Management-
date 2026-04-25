import { z } from "zod";

const vehicleProfileSchema = z.object({
  id: z.string(),
  make: z.string(),
  model: z.string(),
  year: z.number(),
  fuelType: z.enum(["gasoline", "diesel", "hybrid", "electric"]),
  mpg: z.number().optional(),
  miPerKwh: z.number().optional(),
  currentOdometerMiles: z.number().optional(),
  homeArea: z.string().optional(),
  preferredFuelProduct: z.enum(["regular", "midgrade", "premium", "diesel", "electric", "flexible"]),
  stationPreference: z.enum(["cheapest", "balanced", "premiumQuality", "promoHunter"]),
  prioritizePromos: z.boolean(),
  weeklyMiles: z.number(),
  commonRoutes: z.array(z.string())
});

const tripResultSchema = z.object({
  id: z.string(),
  endedAt: z.string(),
  durationSeconds: z.number(),
  distanceMiles: z.number().optional(),
  avgSpeedMph: z.number().optional(),
  maxSpeedMph: z.number().optional(),
  hardBrakes: z.number(),
  sharpTurns: z.number(),
  aggressiveAccels: z.number(),
  bumpsDetected: z.number(),
  mpg: z.number(),
  estimatedGallons: z.number().optional(),
  estimatedFuelCost: z.number().optional(),
  aiTripSummary: z.string().optional(),
  aiDrivingBehavior: z.string().optional(),
  aiFuelInsight: z.string().optional(),
  aiRoadImpact: z.string().optional(),
  aiBrakeWear: z.string().optional(),
  aiOverallTip: z.string().optional()
});

const fuelLogSchema = z.object({
  id: z.string(),
  loggedAt: z.string(),
  stationName: z.string(),
  areaLabel: z.string(),
  fuelProduct: z.string(),
  pricePerUnit: z.number(),
  amount: z.number(),
  promoTitle: z.string().optional(),
  totalCost: z.number()
});

const maintenanceReminderSchema = z.object({
  id: z.string(),
  serviceType: z.enum(["oilChange", "tireRotation", "brakeInspection", "coolant", "airFilter"]),
  intervalMiles: z.number(),
  lastServiceOdometer: z.number().optional(),
  lastServiceDate: z.string().optional()
});

const maintenanceExpenseSchema = z.object({
  id: z.string(),
  purchasedAt: z.string(),
  category: z.string(),
  itemName: z.string(),
  purchaseLocation: z.string(),
  totalCost: z.number(),
  notes: z.string().optional()
});

export const fuelSummaryRequestSchema = z.object({
  userId: z.string(),
  profile: vehicleProfileSchema,
  trips: z.array(tripResultSchema),
  fuelLogs: z.array(fuelLogSchema)
});

export const maintenanceAnalyzeRequestSchema = z.object({
  userId: z.string(),
  profile: vehicleProfileSchema,
  reminders: z.array(maintenanceReminderSchema),
  trips: z.array(tripResultSchema),
  expenses: z.array(maintenanceExpenseSchema)
});

export const copilotQueryRequestSchema = z.object({
  userId: z.string(),
  query: z.string().min(1)
});

export const voiceSummaryRequestSchema = z.object({
  userId: z.string(),
  context: z.enum(["fuel", "maintenance", "copilot"]),
  transcript: z.string().min(1)
});
