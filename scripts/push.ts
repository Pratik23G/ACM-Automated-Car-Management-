/**
 * Pushes ACM Vapi resources (tools → assistants → squad) to the Vapi API.
 * Usage: npm run push:dev  |  npm run push:prod
 */

import fs from 'fs'
import path from 'path'
import { parse as parseYaml } from 'yaml'
import { VapiClient } from '@vapi-ai/server-sdk'

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const org = process.argv[2] ?? 'dev'
const envFile = `.env.${org}`

// Load env file manually (no dotenv dependency)
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const [key, ...rest] = trimmed.split('=')
    if (key && !process.env[key]) process.env[key] = rest.join('=').trim()
  }
}

const VAPI_API_KEY = process.env.VAPI_API_KEY
if (!VAPI_API_KEY) {
  console.error(`❌  VAPI_API_KEY not set. Add it to ${envFile}`)
  process.exit(1)
}

const vapi = new VapiClient({ token: VAPI_API_KEY })
const resourceDir = `resources/${org}`

// State file maps resource names → Vapi UUIDs so we update instead of duplicate
const stateFile = `.vapi-state.${org}.json`
const state: Record<string, string> = fs.existsSync(stateFile)
  ? JSON.parse(fs.readFileSync(stateFile, 'utf8'))
  : {}

function saveState() {
  fs.writeFileSync(stateFile, JSON.stringify(state, null, 2))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readYaml(filePath: string) {
  return parseYaml(fs.readFileSync(filePath, 'utf8'))
}

/** Parse YAML frontmatter + body from an .md file */
function readMd(filePath: string): { frontmatter: Record<string, unknown>; body: string } {
  const raw = fs.readFileSync(filePath, 'utf8')
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
  if (!match) throw new Error(`No YAML frontmatter found in ${filePath}`)
  return {
    frontmatter: parseYaml(match[1]),
    body: match[2].trim(),
  }
}

function slugFromPath(filePath: string) {
  return path.basename(filePath, path.extname(filePath))
}

// ---------------------------------------------------------------------------
// Step 1: Push tools
// ---------------------------------------------------------------------------

async function pushTools(): Promise<Record<string, string>> {
  const toolsDir = path.join(resourceDir, 'tools')
  const toolNameToId: Record<string, string> = {}

  for (const file of fs.readdirSync(toolsDir).filter(f => f.endsWith('.yml'))) {
    const slug = slugFromPath(file)
    const raw = readYaml(path.join(toolsDir, file))

    const createPayload = {
      type: 'function' as const,
      async: raw.async ?? false,
      messages: raw.messages,
      function: raw.function,
      server: raw.server,
    }

    let id = state[`tool:${slug}`]
    if (id) {
      await vapi.tools.update({ id, body: { function: createPayload.function, server: createPayload.server } } as never)
      console.log(`  ✅  tool updated:  ${slug} (${id})`)
    } else {
      const created = await vapi.tools.create(createPayload as never)
      id = (created as { id: string }).id
      state[`tool:${slug}`] = id
      console.log(`  ✅  tool created:  ${slug} (${id})`)
    }
    toolNameToId[slug] = id
    saveState()
  }

  return toolNameToId
}

// ---------------------------------------------------------------------------
// Step 2: Push assistants
// ---------------------------------------------------------------------------

async function pushAssistants(
  toolNameToId: Record<string, string>,
): Promise<Record<string, string>> {
  const assistantsDir = path.join(resourceDir, 'assistants')
  const assistantNameToId: Record<string, string> = {}

  for (const file of fs.readdirSync(assistantsDir).filter(f => f.endsWith('.md'))) {
    const slug = slugFromPath(file)
    const { frontmatter, body } = readMd(path.join(assistantsDir, file))

    // Resolve tool name slugs → Vapi UUIDs
    const toolIds: string[] = ((frontmatter.model as Record<string, unknown>)?.toolIds as string[] ?? [])
      .map((name: string) => {
        const id = toolNameToId[name]
        if (!id) throw new Error(`Tool "${name}" not found in state — push tools first`)
        return id
      })

    const payload = {
      name: frontmatter.name,
      voice: frontmatter.voice,
      model: {
        ...frontmatter.model as object,
        toolIds,
        messages: [{ role: 'system', content: body }],
      },
      firstMessage: frontmatter.firstMessage,
    }

    let id = state[`assistant:${slug}`]
    if (id) {
      await vapi.assistants.update({ id, ...payload } as never)
      console.log(`  ✅  assistant updated:  ${slug} (${id})`)
    } else {
      const created = await vapi.assistants.create(payload as never)
      id = (created as { id: string }).id
      state[`assistant:${slug}`] = id
      console.log(`  ✅  assistant created:  ${slug} (${id})`)
    }
    assistantNameToId[slug] = id
    saveState()
  }

  return assistantNameToId
}

// ---------------------------------------------------------------------------
// Step 3: Push squads
// ---------------------------------------------------------------------------

async function pushSquads(assistantNameToId: Record<string, string>) {
  const squadsDir = path.join(resourceDir, 'squads')

  for (const file of fs.readdirSync(squadsDir).filter(f => f.endsWith('.yml'))) {
    const slug = slugFromPath(file)
    const raw = readYaml(path.join(squadsDir, file))

    // Resolve assistant slugs → Vapi UUIDs in members + destinations
    const members = (raw.members as Array<Record<string, unknown>>).map((member) => {
      const assistantId = assistantNameToId[member.assistantId as string]
      if (!assistantId) throw new Error(`Assistant "${member.assistantId}" not found in state`)

      const destinations = ((member.assistantDestinations ?? []) as Array<Record<string, unknown>>).map(
        (dest) => ({
          type: dest.type,
          assistantId: assistantNameToId[dest.assistantId as string] ?? dest.assistantId,
          description: dest.description,
        }),
      )

      return { assistantId, assistantDestinations: destinations }
    })

    const payload = { name: raw.name, members }

    let id = state[`squad:${slug}`]
    if (id) {
      await vapi.squads.update({ id, ...payload } as never)
      console.log(`  ✅  squad updated:  ${slug} (${id})`)
    } else {
      const created = await vapi.squads.create(payload as never)
      id = (created as { id: string }).id
      state[`squad:${slug}`] = id
      console.log(`  ✅  squad created:  ${slug} (${id})`)
    }
    saveState()
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

console.log(`\n🚀  Pushing ACM resources → Vapi (org: ${org})\n`)

console.log('📦  Tools...')
const toolNameToId = await pushTools()

console.log('\n🤖  Assistants...')
const assistantNameToId = await pushAssistants(toolNameToId)

console.log('\n🧑‍🤝‍🧑  Squads...')
await pushSquads(assistantNameToId)

console.log(`\n✅  Done. State saved to ${stateFile}\n`)
