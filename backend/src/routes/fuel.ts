import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import {
  FuelSummaryQuerySchema,
  CheapestNearbyQuerySchema,
  FuelMarketSummary,
  StationRecommendation,
} from '../models/schemas.js'
import redis from '../providers/redisClient.js'

const FUEL_INGEST_KEY = 'fuel:sf_zone:latest'
const FUEL_TTL = 93600 // 26 hours

export default async function fuelRoutes(fastify: FastifyInstance) {
  fastify.get('/fuel/summary', async (
    request: FastifyRequest,
    reply: FastifyReply,
  ) => {
    const query = FuelSummaryQuerySchema.safeParse(request.query)
    if (!query.success) {
      return reply.status(400).send({ error: query.error.flatten() })
    }

    const { vehicle_id } = query.data

    // TODO: Load vehicle's primary driving zone from TigerData profile
    // TODO: Fetch cached prices from Redis key `fuel:prices:{zone}` (TTL: 30 min)
    // TODO: On cache miss, call fuel price provider API (GasBuddy / OPIS / DOE EIA) for zone
    // TODO: Load vehicle's avg MPG and weekly mileage from TigerData
    // TODO: Compute weeklyCommuteCostUSD = (weeklyMiles / avgMpg) * localAvgPricePerGallon
    // TODO: Load last week's cached summary to compute weekOverWeekDelta
    // TODO: Cache new summary in Redis key `fuel:summary:{vehicle_id}` (TTL: 30 min)

    const summary: FuelMarketSummary = {
      vehicleId: vehicle_id,
      zone: 'route-9-corridor',
      localAvgPricePerGallon: 3.65,
      cheapestPricePerGallon: 3.47,
      cheapestStationName: 'Shell on Route 9',
      cheapestStationDistanceMiles: 0.8,
      weekOverWeekDelta: -0.06,
      weeklyCommuteCostUSD: 42.30,
      projectedMonthlyFuelCostUSD: 183.20,
      updatedAt: new Date().toISOString(),
    }

    return reply.status(200).send(summary)
  })

  fastify.get('/fuel/cheapest-nearby', async (
    request: FastifyRequest,
    reply: FastifyReply,
  ) => {
    const query = CheapestNearbyQuerySchema.safeParse(request.query)
    if (!query.success) {
      return reply.status(400).send({ error: query.error.flatten() })
    }

    const { vehicle_id, max_distance_miles } = query.data

    // TODO: Resolve vehicle's current location from Redis session key `vehicle:location:{vehicle_id}`
    //       or fall back to home location from TigerData
    // TODO: Query fuel price provider for stations within max_distance_miles radius
    // TODO: Sort results by pricePerGallon ascending
    // TODO: Compute savingsVsLocalAvg for each station
    // TODO: Cache in Redis key `fuel:nearby:{lat}:{lng}:{radius}` (TTL: 30 min)

    const allStations: StationRecommendation[] = [
      {
        stationId: 'station-001',
        name: 'Shell',
        brand: 'Shell',
        address: '123 Route 9, Anytown',
        distanceMiles: 0.8,
        pricePerGallon: 3.47,
        fuelGrade: 'regular',
        savingsVsLocalAvg: 0.18,
        lastUpdated: new Date().toISOString(),
      },
      {
        stationId: 'station-002',
        name: 'Costco Gas',
        brand: 'Costco',
        address: '456 Commerce Blvd, Anytown',
        distanceMiles: 1.4,
        pricePerGallon: 3.39,
        fuelGrade: 'regular',
        savingsVsLocalAvg: 0.26,
        lastUpdated: new Date().toISOString(),
      },
      {
        stationId: 'station-003',
        name: 'BP',
        brand: 'BP',
        address: '789 Main St, Anytown',
        distanceMiles: 1.9,
        pricePerGallon: 3.59,
        fuelGrade: 'regular',
        savingsVsLocalAvg: 0.06,
        lastUpdated: new Date().toISOString(),
      },
    ]

    const stations = allStations
      .filter((s) => s.distanceMiles <= max_distance_miles)
      .sort((a, b) => a.pricePerGallon - b.pricePerGallon)

    return reply.status(200).send({ vehicle_id, stations })
  })

  // POST /fuel/ingest — called by Nexla pipeline, stores snapshot in Redis
  fastify.post('/fuel/ingest', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = request.body as {
      zone: string
      avg_price_usd: number
      cheapest_station_price: number
      cheapest_station_name?: string
      timestamp: string
    }
    if (!body) return reply.status(400).send({ error: 'Missing body' })

    await redis.setex(FUEL_INGEST_KEY, FUEL_TTL, JSON.stringify(body))
    return reply.status(200).send({ ok: true, key: FUEL_INGEST_KEY })
  })

  // GET /fuel/current — read latest fuel snapshot from Redis
  fastify.get('/fuel/current', async (_request: FastifyRequest, reply: FastifyReply) => {
    const data = await redis.get(FUEL_INGEST_KEY)
    if (!data) return reply.status(404).send({ error: 'No fuel snapshot found. Pipeline may not have run yet.' })
    return reply.status(200).send(JSON.parse(data))
  })
}
