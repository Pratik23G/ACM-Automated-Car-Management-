import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import {
  MaintenanceEstimatesQuerySchema,
  MaintenanceEstimate,
  MaintenanceComponent,
} from '../models/schemas.js'

const ALL_COMPONENTS: MaintenanceComponent[] = [
  'oil',
  'brakes',
  'tires',
  'coolant',
  'air_filter',
]

export default async function maintenanceRoutes(fastify: FastifyInstance) {
  fastify.get('/maintenance/estimates', async (
    request: FastifyRequest,
    reply: FastifyReply,
  ) => {
    const query = MaintenanceEstimatesQuerySchema.safeParse(request.query)
    if (!query.success) {
      return reply.status(400).send({ error: query.error.flatten() })
    }

    const { vehicle_id, component } = query.data

    // TODO: Check Redis cache `maintenance:estimates:{vehicle_id}` (TTL: 15 min)
    // TODO: On cache miss, load latest MaintenanceEstimate[] from TigerData for vehicle
    // TODO: Filter to requested component(s)
    // TODO: If no data exists yet, return estimates at base OEM intervals with urgency: 'normal'

    const components = component === 'all' ? ALL_COMPONENTS : [component as MaintenanceComponent]

    const estimates: MaintenanceEstimate[] = components.map((c) => ({
      component: c,
      baseIntervalMiles: 5000,
      adjustedIntervalMiles: 4500,
      dueMileage: 68000,
      currentMileage: 63000,
      urgency: 'normal' as const,
      confidenceScore: 0.75,
      explanation: `${c} maintenance is on a standard schedule. No aggressive driving patterns detected for this component.`,
      topFactors: [],
    }))

    return reply.status(200).send({ vehicle_id, estimates })
  })
}
