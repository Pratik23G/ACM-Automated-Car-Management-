import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { FuelSnapshotSchema, FuelSnapshot } from '../models/schemas.js'
import { storeSet, storeGet } from '../lib/store.js'

const redisKey = (zone: string) => `fuel:${zone}:latest`
const TTL_SECONDS = 60 * 60 * 26 // 26 hours

export default async function fuelIngestRoutes(fastify: FastifyInstance) {
  fastify.post('/fuel/ingest', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = FuelSnapshotSchema.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: body.error.flatten() })
    }
    const snapshot = body.data
    await storeSet(redisKey(snapshot.zone), JSON.stringify(snapshot), TTL_SECONDS)
    return reply.status(200).send({ ok: true, key: redisKey(snapshot.zone) })
  })

  fastify.get('/fuel/current', async (
    request: FastifyRequest<{ Querystring: { zone?: string } }>,
    reply: FastifyReply,
  ) => {
    const zone = request.query.zone ?? 'sf_common_routes'
    const raw = await storeGet(redisKey(zone))
    if (!raw) {
      return reply.status(404).send({ error: 'No fuel snapshot found. Pipeline may not have run yet.' })
    }
    return reply.status(200).send(JSON.parse(raw) as FuelSnapshot)
  })
}
