import dotenv from 'dotenv'
dotenv.config({ path: '../.env.dev' })
import Fastify from 'fastify'
import cors from '@fastify/cors'
import tripRoutes from './routes/trip.js'
import maintenanceRoutes from './routes/maintenance.js'
import fuelRoutes from './routes/fuel.js'
import weatherRoutes from './routes/weather.js'
import { vapiRoutes } from './vapi/vapiRoutes.js'

const server = Fastify({ logger: true })

await server.register(cors)
await server.register(tripRoutes)
await server.register(maintenanceRoutes)
await server.register(fuelRoutes)
await server.register(weatherRoutes)
await server.register(vapiRoutes)

server.get('/health', async () => ({ status: 'ok' }))

const port = Number(process.env.PORT ?? 3000)
await server.listen({ port, host: '0.0.0.0' })
