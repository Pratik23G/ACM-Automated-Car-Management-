import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import redis from '../providers/redisClient.js'

const KEY = 'weather:sf_default:latest'
const TTL = 7200 // 2 hours

export default async function weatherRoutes(fastify: FastifyInstance) {
  fastify.post('/weather/ingest', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = request.body as Record<string, unknown>
    if (!body) return reply.status(400).send({ error: 'Missing body' })

    await redis.setex(KEY, TTL, JSON.stringify(body))
    return reply.status(200).send({ ok: true, key: KEY })
  })

  fastify.get('/weather/current', async (_request: FastifyRequest, reply: FastifyReply) => {
    const data = await redis.get(KEY)
    if (!data) return reply.status(404).send({ error: 'No weather snapshot found. Pipeline may not have run yet.' })
    return reply.status(200).send(JSON.parse(data))
  })
}
