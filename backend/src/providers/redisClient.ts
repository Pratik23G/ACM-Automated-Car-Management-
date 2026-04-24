import { Redis } from 'ioredis'

const redis = new Redis(process.env.REDIS_URL!)

redis.on('connect', () => console.log('Redis connected ✅'))
redis.on('error', (err: Error) => console.error('Redis error:', err))

export default redis
