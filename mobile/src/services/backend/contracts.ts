import { CopilotQueryResponse, DailyBrief, FuelSummary, MaintenanceAnalysis, VoiceSummaryResponse } from "../../models/agent";
import { FuelLog, MaintenanceExpense, MaintenanceReminder, TripResult } from "../../models/trip";
import { VehicleProfile } from "../../models/vehicle";

export interface FuelSummaryRequest {
  userId: string;
  profile: VehicleProfile;
  trips: TripResult[];
  fuelLogs: FuelLog[];
}

export interface MaintenanceAnalyzeRequest {
  userId: string;
  profile: VehicleProfile;
  reminders: MaintenanceReminder[];
  trips: TripResult[];
  expenses: MaintenanceExpense[];
}

export interface CopilotQueryRequest {
  userId: string;
  query: string;
}

export interface VoiceSummaryRequest {
  userId: string;
  context: "fuel" | "maintenance" | "copilot";
  transcript: string;
}

export type FuelSummaryResponse = FuelSummary;
export type MaintenanceAnalyzeResponse = MaintenanceAnalysis;
export type DailyBriefResponse = DailyBrief;
export type VoiceSummaryApiResponse = VoiceSummaryResponse;
export type CopilotQueryApiResponse = CopilotQueryResponse;
