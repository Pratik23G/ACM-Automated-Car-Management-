import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { FinalizeTripRequestSchema, MaintenanceEstimate } from '../models/schemas.js'

export default async function tripRoutes(fastify: FastifyInstance) {
  fastify.post('/trip/finalize', async (
    request: FastifyRequest,
    reply: FastifyReply,
  ) => {
    const body = FinalizeTripRequestSchema.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: body.error.flatten() })
    }

    const { vehicle_id, trip_id } = body.data

    // TODO: Pull raw trip events from Redis key `trip:{vehicle_id}:{trip_id}:events`
    // TODO: Compute TripTelemetrySummary (hard brakes, sharp turns, accel patterns, per-10-mile rates)
    // TODO: Load current MaintenanceEstimate[] for vehicle from TigerData
    // TODO: Run interval adjustment model: multiply base intervals by driving behavior multipliers
    // TODO: Persist updated MaintenanceEstimate[] back to TigerData
    // TODO: Write new estimates to Redis cache `maintenance:estimates:{vehicle_id}` (TTL: 15 min)
    // TODO: Publish AgentAction { type: 'update_maintenance_estimate' } to vehicle event stream

    const estimates: MaintenanceEstimate[] = [
      {
        component: 'oil',
        baseIntervalMiles: 5000,
        adjustedIntervalMiles: 4200,
        dueMileage: 67200,
        currentMileage: 63000,
        urgency: 'elevated',
        confidenceScore: 0.87,
        explanation:
          'Your oil change interval shortened because your hard-braking rate is 2.9x your baseline over the last 8 trips.',
        topFactors: [
          {
            metric: 'hard_brake_rate',
            value: 2.9,
            baseline: 1.0,
            multiplier: 0.84,
            description: 'Hard-braking rate is 2.9x your baseline',
          },
        ],
      },
    ]

    return reply.status(200).send({ vehicle_id, trip_id, estimates })
  })
}
