import { z } from 'zod'

// ---------------------------------------------------------------------------
// Trip telemetry
// ---------------------------------------------------------------------------

export const TripTelemetrySummarySchema = z.object({
  tripId: z.string(),
  vehicleId: z.string(),
  startedAt: z.string().datetime(),
  endedAt: z.string().datetime(),
  distanceMiles: z.number(),
  hardBrakeCount: z.number().int(),
  hardBrakeRate: z.number(),       // events per 10 miles
  sharpTurnCount: z.number().int(),
  sharpTurnRate: z.number(),       // events per 10 miles
  hardAccelCount: z.number().int(),
  hardAccelRate: z.number(),       // events per 10 miles
  avgBrakingG: z.number(),
  avgTurnG: z.number(),
  maxSpeedMph: z.number(),
  idleMinutes: z.number(),
})
export type TripTelemetrySummary = z.infer<typeof TripTelemetrySummarySchema>

// ---------------------------------------------------------------------------
// Maintenance
// ---------------------------------------------------------------------------

export const MaintenanceComponentSchema = z.enum([
  'oil',
  'brakes',
  'tires',
  'coolant',
  'air_filter',
])
export type MaintenanceComponent = z.infer<typeof MaintenanceComponentSchema>

export const UrgencySchema = z.enum(['normal', 'elevated', 'high', 'critical'])
export type Urgency = z.infer<typeof UrgencySchema>

export const MaintenanceFactorSchema = z.object({
  metric: z.string(),       // e.g. "hard_brake_rate"
  value: z.number(),        // observed value
  baseline: z.number(),     // expected baseline
  multiplier: z.number(),   // how much this metric shifted the interval (< 1 = shorter)
  description: z.string(),  // e.g. "Hard-braking rate is 2.9x your baseline"
})
export type MaintenanceFactor = z.infer<typeof MaintenanceFactorSchema>

export const MaintenanceEstimateSchema = z.object({
  component: MaintenanceComponentSchema,
  baseIntervalMiles: z.number(),
  adjustedIntervalMiles: z.number(),
  dueMileage: z.number(),
  currentMileage: z.number(),
  urgency: UrgencySchema,
  confidenceScore: z.number().min(0).max(1),
  explanation: z.string(),  // plain-English sentence for the voice agent to read
  topFactors: z.array(MaintenanceFactorSchema),
})
export type MaintenanceEstimate = z.infer<typeof MaintenanceEstimateSchema>

// ---------------------------------------------------------------------------
// Agent actions
// ---------------------------------------------------------------------------

export const AgentActionTypeSchema = z.enum([
  'notify_user',
  'update_maintenance_estimate',
  'recommend_fill_up',
  'show_pretrip_brief',
])
export type AgentActionType = z.infer<typeof AgentActionTypeSchema>

export const AgentActionSchema = z.object({
  type: AgentActionTypeSchema,
  vehicleId: z.string(),
  payload: z.record(z.unknown()),
  triggeredAt: z.string().datetime(),
  agentId: z.string().optional(),
})
export type AgentAction = z.infer<typeof AgentActionSchema>

// ---------------------------------------------------------------------------
// Fuel market
// ---------------------------------------------------------------------------

export const FuelMarketSummarySchema = z.object({
  vehicleId: z.string(),
  zone: z.string(),                        // primary driving zone label
  localAvgPricePerGallon: z.number(),
  cheapestPricePerGallon: z.number(),
  cheapestStationName: z.string(),
  cheapestStationDistanceMiles: z.number(),
  weekOverWeekDelta: z.number(),           // positive = prices went up
  weeklyCommuteCostUSD: z.number(),
  projectedMonthlyFuelCostUSD: z.number(),
  updatedAt: z.string().datetime(),
})
export type FuelMarketSummary = z.infer<typeof FuelMarketSummarySchema>

export const StationRecommendationSchema = z.object({
  stationId: z.string(),
  name: z.string(),
  brand: z.string(),
  address: z.string(),
  distanceMiles: z.number(),
  pricePerGallon: z.number(),
  fuelGrade: z.string(),               // "regular" | "mid" | "premium"
  savingsVsLocalAvg: z.number(),       // dollars saved per gallon vs local average
  lastUpdated: z.string().datetime(),
})
export type StationRecommendation = z.infer<typeof StationRecommendationSchema>

// ---------------------------------------------------------------------------
// Route request/query schemas (validated at API boundary)
// ---------------------------------------------------------------------------

export const FinalizeTripRequestSchema = z.object({
  vehicle_id: z.string(),
  trip_id: z.string(),
})
export type FinalizeTripRequest = z.infer<typeof FinalizeTripRequestSchema>

export const MaintenanceEstimatesQuerySchema = z.object({
  vehicle_id: z.string(),
  component: z.enum(['oil', 'brakes', 'tires', 'coolant', 'air_filter', 'all']),
})
export type MaintenanceEstimatesQuery = z.infer<typeof MaintenanceEstimatesQuerySchema>

export const FuelSummaryQuerySchema = z.object({
  vehicle_id: z.string(),
})
export type FuelSummaryQuery = z.infer<typeof FuelSummaryQuerySchema>

export const CheapestNearbyQuerySchema = z.object({
  vehicle_id: z.string(),
  max_distance_miles: z.coerce.number().positive().default(2),
})
export type CheapestNearbyQuery = z.infer<typeof CheapestNearbyQuerySchema>

// ---------------------------------------------------------------------------
// Weather
// ---------------------------------------------------------------------------

export const WeatherSnapshotSchema = z.object({
  location: z.string(),
  lat: z.number(),
  lon: z.number(),
  temperature_c: z.number(),
  precipitation_mm: z.number(),
  wind_speed_kmh: z.number(),
  weather_code: z.number().int(),
  timestamp: z.string().datetime(),
})
export type WeatherSnapshot = z.infer<typeof WeatherSnapshotSchema>

export const WeatherRiskFactorSchema = z.object({
  coolantStressMultiplier: z.number(),   // 1.0 = no change, >1 = more stress
  oilIntervalMultiplier: z.number(),     // <1 = shorter interval
  tireWearMultiplier: z.number(),        // >1 = faster wear
  heatCycleIncrement: z.number().int(), // 0 or 1 per day
  reasons: z.array(z.string()),
})
export type WeatherRiskFactor = z.infer<typeof WeatherRiskFactorSchema>

// ---------------------------------------------------------------------------
// Fuel ingest
// ---------------------------------------------------------------------------

export const FuelSnapshotSchema = z.object({
  zone: z.string(),
  avg_price_usd: z.number(),
  cheapest_station_price: z.number(),
  cheapest_station_name: z.string(),
  timestamp: z.string().datetime(),
})
export type FuelSnapshot = z.infer<typeof FuelSnapshotSchema>
