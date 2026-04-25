import { RedisMemoryProvider } from "../../providers/RedisMemoryProvider.js";
import { ModelProvider } from "../../providers/ModelProvider.js";
import {
  AgentAction,
  CopilotCard,
  MaintenanceAnalysis,
  MaintenanceEstimate,
  MaintenanceReminder,
  MaintenanceServiceType,
  TripResult,
  VehicleProfile
} from "../../domain/models/types.js";
import { average, daysToText } from "../../utils/math.js";
import { makeId } from "../../utils/id.js";

interface MaintenanceAnalyzeInput {
  userId: string;
  profile: VehicleProfile;
  reminders: MaintenanceReminder[];
  trips: TripResult[];
  expenses: unknown[];
}

const baseIntervals: Record<MaintenanceServiceType, number> = {
  oilChange: 5000,
  tireRotation: 7500,
  brakeInspection: 15000,
  coolant: 30000,
  airFilter: 15000
};

export class MaintenanceAgentService {
  constructor(private readonly model: ModelProvider, private readonly memory: RedisMemoryProvider) {}

  async analyze(input: MaintenanceAnalyzeInput): Promise<MaintenanceAnalysis> {
    const currentOdometer =
      (input.profile.currentOdometerMiles ?? 0) +
      input.trips.reduce((sum, trip) => sum + (trip.distanceMiles ?? 0), 0);

    const avgHardBrakes = average(input.trips.map((trip) => trip.hardBrakes));
    const avgSharpTurns = average(input.trips.map((trip) => trip.sharpTurns));
    const avgAggression = average(
      input.trips.map((trip) => trip.hardBrakes * 3 + trip.sharpTurns * 2 + trip.aggressiveAccels * 2)
    );

    const reminderMap = new Map(input.reminders.map((reminder) => [reminder.serviceType, reminder]));
    const estimates = (Object.keys(baseIntervals) as MaintenanceServiceType[]).map((serviceType) =>
      this.estimateService({
        serviceType,
        reminder: reminderMap.get(serviceType),
        currentOdometer,
        avgHardBrakes,
        avgSharpTurns,
        avgAggression,
        weeklyMiles: input.profile.weeklyMiles || 140
      })
    );

    const ai = await this.model.buildMaintenanceNarrative({
      profile: input.profile,
      estimates
    });

    const response: MaintenanceAnalysis = {
      estimates,
      cards: [...this.buildSystemCards(estimates), ...ai.cards],
      actions: [...this.buildActions(estimates), ...ai.actions]
    };

    await this.memory.rememberSnapshot(input.userId, "maintenance", response);
    await this.memory.rememberSnapshot(input.userId, "profile", input.profile);
    await this.memory.rememberSnapshot(input.userId, "trips", input.trips);
    return response;
  }

  private estimateService(input: {
    serviceType: MaintenanceServiceType;
    reminder?: MaintenanceReminder;
    currentOdometer: number;
    avgHardBrakes: number;
    avgSharpTurns: number;
    avgAggression: number;
    weeklyMiles: number;
  }): MaintenanceEstimate {
    const baseInterval = input.reminder?.intervalMiles ?? baseIntervals[input.serviceType];
    const adjustedInterval = Math.max(500, Math.round(baseInterval * (1 - this.reductionFactor(input)) / 100) * 100);
    const lastServiceOdometer = input.reminder?.lastServiceOdometer ?? 0;
    const milesSinceService = input.currentOdometer - lastServiceOdometer;
    const dueInMiles = Math.round(adjustedInterval - milesSinceService);
    const severity: MaintenanceEstimate["severity"] =
      dueInMiles <= 0 ? "overdue" : dueInMiles <= 500 ? "soon" : "ok";
    const dueWeeks = dueInMiles <= 0 ? 0 : dueInMiles / Math.max(input.weeklyMiles, 1);

    return {
      serviceType: input.serviceType,
      adjustedIntervalMiles: adjustedInterval,
      dueInMiles,
      dueDateLabel: dueInMiles <= 0 ? "Now" : daysToText(dueWeeks * 7),
      severity,
      reason: this.reasonText(input.serviceType, input.avgHardBrakes, input.avgSharpTurns, input.avgAggression),
      recommendedAction: severity === "overdue"
        ? "Recommend surfacing an urgent service recommendation."
        : severity === "soon"
          ? "Recommend showing a due-soon banner and a planning nudge."
          : "Keep monitoring this service on the regular cadence."
    };
  }

  private reductionFactor(input: {
    serviceType: MaintenanceServiceType;
    avgHardBrakes: number;
    avgSharpTurns: number;
    avgAggression: number;
  }) {
    switch (input.serviceType) {
      case "brakeInspection":
        return Math.min(input.avgHardBrakes / 4, 1) * 0.4 + Math.min(input.avgAggression / 15, 1) * 0.1;
      case "oilChange":
        return Math.min(input.avgAggression / 15, 1) * 0.3;
      case "tireRotation":
        return Math.min(input.avgSharpTurns / 3, 1) * 0.3 + Math.min(input.avgAggression / 15, 1) * 0.05;
      case "coolant":
        return 0.03;
      case "airFilter":
        return 0.02;
    }
  }

  private reasonText(
    serviceType: MaintenanceServiceType,
    avgHardBrakes: number,
    avgSharpTurns: number,
    avgAggression: number
  ) {
    switch (serviceType) {
      case "brakeInspection":
        return `Brake wear risk rises with ${avgHardBrakes.toFixed(1)} hard brakes per trip and an aggression score of ${avgAggression.toFixed(1)}.`;
      case "oilChange":
        return `Oil interval is being compressed by acceleration-driven engine load with aggression at ${avgAggression.toFixed(1)}.`;
      case "tireRotation":
        return `Tire wear pressure is tied to ${avgSharpTurns.toFixed(1)} sharp turns per trip and route stress.`;
      case "coolant":
        return "Coolant estimate is mostly mileage-based, with only a light behavior adjustment.";
      case "airFilter":
        return "Air filter estimate stays close to the default interval unless the vehicle profile suggests heavy urban usage.";
    }
  }

  private buildSystemCards(estimates: MaintenanceEstimate[]): CopilotCard[] {
    const risky = estimates.filter((estimate) => estimate.severity !== "ok");

    return [
      {
        id: makeId("maintenance-summary"),
        type: "hero",
        title: "Maintenance Agent Snapshot",
        body: risky.length
          ? `${risky.length} services need attention soon based on the current driving and odometer profile.`
          : "No immediate maintenance items need urgent attention right now.",
        tone: risky.length ? "warning" : "success",
        items: estimates.slice(0, 3).map((estimate) => ({
          label: estimate.serviceType,
          value: `${estimate.dueInMiles} mi`
        }))
      }
    ];
  }

  private buildActions(estimates: MaintenanceEstimate[]): AgentAction[] {
    return estimates
      .filter((estimate) => estimate.severity !== "ok")
      .slice(0, 2)
      .map((estimate) => ({
        id: makeId(`maintenance-${estimate.serviceType}`),
        type: "notification" as const,
        title: `Service check: ${estimate.serviceType}`,
        description: estimate.recommendedAction,
        priority: estimate.severity === "overdue" ? "high" : "medium",
        destination: "maintenance"
      }));
  }
}
