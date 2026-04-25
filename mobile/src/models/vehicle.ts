export type FuelType = "gasoline" | "diesel" | "hybrid" | "electric";

export type FuelProduct =
  | "regular"
  | "midgrade"
  | "premium"
  | "diesel"
  | "electric"
  | "flexible";

export type FuelStationPreference =
  | "cheapest"
  | "balanced"
  | "premiumQuality"
  | "promoHunter";

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

export const fuelTypeLabel: Record<FuelType, string> = {
  gasoline: "Gasoline",
  diesel: "Diesel",
  hybrid: "Hybrid",
  electric: "Electric"
};

export const fuelProductLabel: Record<FuelProduct, string> = {
  regular: "Regular",
  midgrade: "Midgrade",
  premium: "Premium",
  diesel: "Diesel",
  electric: "Charge",
  flexible: "Flexible"
};

export const stationPreferenceLabel: Record<FuelStationPreference, string> = {
  cheapest: "Cheapest",
  balanced: "Balanced",
  premiumQuality: "Best Quality",
  promoHunter: "Best Promos"
};
