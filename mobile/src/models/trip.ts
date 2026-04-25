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

export type MaintenanceServiceType =
  | "oilChange"
  | "tireRotation"
  | "brakeInspection"
  | "coolant"
  | "airFilter";

export interface MaintenanceReminder {
  id: string;
  serviceType: MaintenanceServiceType;
  intervalMiles: number;
  lastServiceOdometer?: number;
  lastServiceDate?: string;
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

export interface MaintenanceExpense {
  id: string;
  purchasedAt: string;
  category: string;
  itemName: string;
  purchaseLocation: string;
  totalCost: number;
  notes?: string;
}

export const maintenanceServiceLabel: Record<MaintenanceServiceType, string> = {
  oilChange: "Oil Change",
  tireRotation: "Tire Rotation",
  brakeInspection: "Brake Inspection",
  coolant: "Coolant",
  airFilter: "Air Filter"
};
