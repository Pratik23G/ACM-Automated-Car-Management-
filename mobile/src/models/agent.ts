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
