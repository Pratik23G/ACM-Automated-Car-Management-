# ACM2 Platform Migration

ACM2 now includes a new Expo React Native frontend and a Node + Express + TypeScript backend scaffold for hackathon agent integrations.

## Structure

- `mobile/`: Expo + TypeScript app that replaces the SwiftUI client during migration.
- `backend/`: Express + TypeScript API layer that owns Tinyfish, Redis, Vapi, and model integrations.
- `ACM2/`: Existing SwiftUI code kept as migration reference while the new app is wired up.

## Agent Architecture

### Fuel Agent

- Frontend sends profile, weekly driving data, route habits, and fuel preferences to `POST /fuel/summary`.
- Backend calls Tinyfish for price intelligence and fuel-market signals.
- Backend stores recent summaries and query context in Redis.
- AI model provider creates personalized recommendations and notification decisions.
- Frontend renders returned cards automatically.

### Maintenance Agent

- Frontend sends odometer, service history, and driving behavior to `POST /maintenance/analyze`.
- Backend calculates adjusted service intervals for oil, tires, brakes, coolant, and air filter.
- AI model provider explains estimate changes and recommended actions.
- Frontend renders returned maintenance cards automatically.

### Copilot + Voice

- `GET /copilot/daily-brief` returns a merged daily agent brief.
- `POST /copilot/query` answers typed questions using the latest cached agent context.
- `POST /voice/summary` prepares a Vapi-ready voice brief.

## Frontend Rules

- The mobile app never holds Tinyfish, Redis, Vapi, or model API secrets.
- The only client environment value should be the backend base URL.
- All structured agent responses flow through typed backend clients.

## Backend Rules

- Keep all API keys in `backend/.env`.
- Tinyfish, Redis, Vapi, and LLM calls live only in backend providers.
- Controllers return typed JSON contracts that the app can render as cards and actions.

## Next Integration Steps

1. Install workspace dependencies with `npm install` at the repo root.
2. Fill in `backend/.env` using `backend/.env.example`.
3. Replace the stub provider methods with real Tinyfish, Redis, Vapi, and model calls.
4. Point Expo to your backend URL with `EXPO_PUBLIC_API_BASE_URL`.
5. Remove SwiftUI entry points only after the Expo flow reaches feature parity you want.
