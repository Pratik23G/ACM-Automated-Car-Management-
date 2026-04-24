import { WeatherSnapshot, WeatherRiskFactor } from '../../models/schemas.js'

const HOT_THRESHOLD_C = 35
const COLD_THRESHOLD_C = 5
const RAIN_THRESHOLD_MM = 5
const HEAT_CYCLE_THRESHOLD_C = 30

/**
 * Derives maintenance risk multipliers from a weather snapshot.
 * Output is applied on top of driving-behavior scores in MaintenanceEstimate computation.
 */
export function weatherRiskModifier(weather: WeatherSnapshot): WeatherRiskFactor {
  let coolantStressMultiplier = 1.0
  let oilIntervalMultiplier = 1.0
  let tireWearMultiplier = 1.0
  let heatCycleIncrement = 0
  const reasons: string[] = []

  if (weather.temperature_c > HOT_THRESHOLD_C) {
    coolantStressMultiplier = 1.15
    reasons.push(`High temp (${weather.temperature_c}°C) increases coolant stress by 15%`)
  }

  if (weather.temperature_c < COLD_THRESHOLD_C) {
    oilIntervalMultiplier = 0.90
    reasons.push(`Cold temp (${weather.temperature_c}°C) shortens oil interval by 10% — cold starts degrade oil faster`)
  }

  if (weather.precipitation_mm > RAIN_THRESHOLD_MM) {
    tireWearMultiplier = 1.10
    reasons.push(`Rain (${weather.precipitation_mm}mm) increases tire wear by 10%`)
  }

  if (weather.temperature_c > HEAT_CYCLE_THRESHOLD_C) {
    heatCycleIncrement = 1
    reasons.push(`Heat cycle recorded — temp above ${HEAT_CYCLE_THRESHOLD_C}°C`)
  }

  return {
    coolantStressMultiplier,
    oilIntervalMultiplier,
    tireWearMultiplier,
    heatCycleIncrement,
    reasons,
  }
}

/**
 * Applies weather risk factors to a base maintenance interval.
 * Returns the adjusted interval in miles.
 */
export function applyWeatherToInterval(
  baseIntervalMiles: number,
  component: string,
  risk: WeatherRiskFactor,
): number {
  switch (component) {
    case 'coolant':
      return Math.round(baseIntervalMiles / risk.coolantStressMultiplier)
    case 'oil':
      return Math.round(baseIntervalMiles * risk.oilIntervalMultiplier)
    case 'tires':
      return Math.round(baseIntervalMiles / risk.tireWearMultiplier)
    default:
      return baseIntervalMiles
  }
}
