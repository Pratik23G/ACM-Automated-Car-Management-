import { DailyBrief } from "../models/agent";
import {
  FuelLog,
  MaintenanceExpense,
  MaintenanceReminder,
  TripResult
} from "../models/trip";

export function makeSeedTrips(): TripResult[] {
  return [
    {
      id: "trip-1",
      endedAt: new Date().toISOString(),
      durationSeconds: 2280,
      distanceMiles: 18.2,
      avgSpeedMph: 28.4,
      maxSpeedMph: 57.1,
      hardBrakes: 2,
      sharpTurns: 1,
      aggressiveAccels: 3,
      bumpsDetected: 1,
      mpg: 26.7,
      estimatedGallons: 0.68,
      estimatedFuelCost: 2.89,
      aiTripSummary: "Downtown traffic kept the trip shorter but less efficient than your open-road average.",
      aiDrivingBehavior: "Acceleration pressure was the main contributor to wasted fuel this trip.",
      aiFuelInsight: "A steadier launch pattern would have saved a small amount on this route.",
      aiRoadImpact: "Road quality looked stable aside from one rough segment.",
      aiBrakeWear: "No major brake-wear spike, but repeated city braking is still accumulating.",
      aiOverallTip: "Leave a little more distance in stop-and-go traffic so you can coast instead of re-accelerating."
    }
  ];
}

export function makeSeedFuelLogs(): FuelLog[] {
  return [
    {
      id: "fuel-1",
      loggedAt: new Date().toISOString(),
      stationName: "Shell",
      areaLabel: "Downtown San Jose",
      fuelProduct: "Regular",
      pricePerUnit: 4.49,
      amount: 11.4,
      promoTitle: "Fuel Rewards",
      totalCost: 51.19
    },
    {
      id: "fuel-2",
      loggedAt: new Date(Date.now() - 8 * 86_400_000).toISOString(),
      stationName: "Costco",
      areaLabel: "Santa Clara",
      fuelProduct: "Regular",
      pricePerUnit: 4.17,
      amount: 10.2,
      totalCost: 42.53
    }
  ];
}

export function makeSeedMaintenanceReminders(): MaintenanceReminder[] {
  return [
    {
      id: "maint-1",
      serviceType: "oilChange",
      intervalMiles: 5000,
      lastServiceOdometer: 45500,
      lastServiceDate: new Date(Date.now() - 120 * 86_400_000).toISOString()
    },
    {
      id: "maint-2",
      serviceType: "tireRotation",
      intervalMiles: 7500,
      lastServiceOdometer: 43000,
      lastServiceDate: new Date(Date.now() - 200 * 86_400_000).toISOString()
    },
    {
      id: "maint-3",
      serviceType: "brakeInspection",
      intervalMiles: 15000
    },
    {
      id: "maint-4",
      serviceType: "coolant",
      intervalMiles: 30000
    },
    {
      id: "maint-5",
      serviceType: "airFilter",
      intervalMiles: 15000
    }
  ];
}

export function makeSeedMaintenanceExpenses(): MaintenanceExpense[] {
  return [
    {
      id: "expense-1",
      purchasedAt: new Date(Date.now() - 35 * 86_400_000).toISOString(),
      category: "Oil",
      itemName: "Synthetic oil + filter",
      purchaseLocation: "AutoZone Santa Clara",
      totalCost: 67.44,
      notes: "Bought after three heavy commute weeks."
    },
    {
      id: "expense-2",
      purchasedAt: new Date(Date.now() - 90 * 86_400_000).toISOString(),
      category: "Tires",
      itemName: "Front tire patch kit",
      purchaseLocation: "America's Tire",
      totalCost: 32.99,
      notes: "Temporary patch before full replacement."
    }
  ];
}

export const seedDailyBrief: DailyBrief = {
  headline: "Fuel pressure looks stable, but brake wear risk is climbing on city-heavy routes.",
  cards: [],
  actions: []
};
