export type FuelType = "gasoline" | "diesel" | "hybrid" | "electric";
export type FuelProduct = "regular" | "midgrade" | "premium" | "diesel" | "electric" | "flexible";
export type FuelStationPreference = "cheapest" | "balanced" | "premiumQuality" | "promoHunter";
export type MaintenanceServiceType = "oilChange" | "tireRotation" | "brakeInspection" | "coolant" | "airFilter";

export interface VehicleProfile {
  id: string;
  make: string;
  model: string;
  year: number;
  fuelType: FuelType;
  mpg?: number;
  miPerKwh?: number;
  currentOdometerMiles?: number;
  homeArea?: string;
  preferredFuelProduct: FuelProduct;
  stationPreference: FuelStationPreference;
  prioritizePromos: boolean;
  weeklyMiles: number;
  commonRoutes: string[];
}

export interface TripResult {
  id: string;
  endedAt: string;
  durationSeconds: number;
  distanceMiles?: number;
  avgSpeedMph?: number;
  maxSpeedMph?: number;
  hardBrakes: number;
  sharpTurns: number;
  aggressiveAccels: number;
  bumpsDetected: number;
  mpg: number;
  estimatedGallons?: number;
  estimatedFuelCost?: number;
  aiTripSummary?: string;
  aiDrivingBehavior?: string;
  aiFuelInsight?: string;
  aiRoadImpact?: string;
  aiBrakeWear?: string;
  aiOverallTip?: string;
}

export interface FuelLog {
  id: string;
  loggedAt: string;
  stationName: string;
  areaLabel: string;
  fuelProduct: string;
  pricePerUnit: number;
  amount: number;
  promoTitle?: string;
  totalCost: number;
}

export interface MaintenanceReminder {
  id: string;
  serviceType: MaintenanceServiceType;
  intervalMiles: number;
  lastServiceOdometer?: number;
  lastServiceDate?: string;
}

export interface MaintenanceExpense {
  id: string;
  purchasedAt: string;
  category: string;
  itemName: string;
  purchaseLocation: string;
  totalCost: number;
  notes?: string;
}

export type CardTone = "info" | "success" | "warning" | "critical";
export type CardType = "hero" | "metric" | "list" | "station" | "timeline" | "summary";
export type ActionPriority = "low" | "medium" | "high";

export interface AgentAction {
  id: string;
  type: "notification" | "voice" | "deep-link" | "recommendation";
  title: string;
  description: string;
  priority: ActionPriority;
  destination?: string;
}

export interface CopilotCardItem {
  label: string;
  value: string;
}

export interface CopilotCard {
  id: string;
  type: CardType;
  title: string;
  body: string;
  tone: CardTone;
  items?: CopilotCardItem[];
  tags?: string[];
  action?: AgentAction;
}

export interface FuelStationSummary {
  name: string;
  areaLabel: string;
  price: number;
  qualitySignal: string;
  savingsNote: string;
}

export interface FuelSummary {
  areaLabel: string;
  fuelProduct: string;
  localAveragePrice: number;
  cheapestStation: FuelStationSummary;
  premiumStation?: FuelStationSummary;
  weeklyCost: number;
  monthlyCost: number;
  yearlyCost: number;
  estimatedSavings: number;
  newsHeadline: string;
  cards: CopilotCard[];
  actions: AgentAction[];
}

export interface MaintenanceEstimate {
  serviceType: string;
  adjustedIntervalMiles: number;
  dueInMiles: number;
  dueDateLabel: string;
  severity: "ok" | "soon" | "overdue";
  reason: string;
  recommendedAction: string;
}

export interface MaintenanceAnalysis {
  estimates: MaintenanceEstimate[];
  cards: CopilotCard[];
  actions: AgentAction[];
}

export interface DailyBrief {
  headline: string;
  cards: CopilotCard[];
  actions: AgentAction[];
}

export interface CopilotQueryResponse {
  answer: string;
  cards: CopilotCard[];
  actions: AgentAction[];
}

export interface VoiceSummaryResponse {
  summary: string;
  cards: CopilotCard[];
  action?: AgentAction;
}

export interface VapiRuntimeConfig {
  backendReady: boolean;
  webSdkReady: boolean;
  squadId?: string;
  squadName?: string;
  publicKey?: string;
  message: string;
}

export interface TinyfishStationIntel {
  name: string;
  areaLabel: string;
  price: number;
  qualitySignal: string;
  reputationScore: number;
  promoSignal?: string;
}

export interface TinyfishNewsItem {
  headline: string;
  summary: string;
  direction: "up" | "steady" | "down";
}

export interface TinyfishFuelIntel {
  stations: TinyfishStationIntel[];
  news: TinyfishNewsItem[];
}
