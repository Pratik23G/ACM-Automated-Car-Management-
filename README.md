# ACM Automated Car Management

ACM is an agentic vehicle intelligence system for maintenance guidance, fuel optimization, trip analytics, and voice copilot flows. The repository now contains the native `ACM2` iOS app, a React Native `mobile` client, and a backend workspace for fuel, maintenance, copilot, and Vapi integration work.

## Project Structure

- `ACM2/`: native SwiftUI iOS app that builds and runs directly in the iOS simulator.
- `ACM2Widget/`: widget extension for quick trip controls and glanceable vehicle state.
- `mobile/`: Expo + TypeScript client used for parallel product and backend iteration.
- `backend/`: Node/TypeScript backend code for fuel, maintenance, telemetry, copilot, and Vapi-connected voice flows.

## Core Capabilities

- Maintenance intelligence that adjusts service intervals based on driving behavior and service history.
- Fuel optimization that surfaces local price signals, route-aware savings opportunities, and fill-up guidance.
- Trip intelligence for route history, driving behavior, and post-trip summaries.
- Voice copilot flows that combine backend memory with Vapi handoff and spoken summaries.

## Architecture Notes

- The mobile and native apps should treat the backend as the integration point for Tinyfish, Redis, Vapi, and model APIs.
- API keys and backend-only credentials belong in backend environment files, not in client bundles.
- The backend currently contains both the newer ACM2 Express-style routes and older Fastify/Vapi scaffolding from previous iterations that are being reconciled over time.

## Current Backend Flow

- `POST /fuel/summary` generates fuel cards and recommendations from vehicle profile and route context.
- `POST /maintenance/analyze` computes maintenance estimates and service urgency.
- `GET /copilot/daily-brief` and `POST /copilot/query` merge cached agent context into one copilot experience.
- `POST /voice/summary` and `GET /vapi/config` support Vapi-oriented voice summary and runtime config flows.

## Validation

- Install dependencies from the repo root with `npm install`.
- Run the backend from the `backend` workspace and point clients at it through environment config.
- Build the `ACM2` Xcode scheme when you want to test the native iOS app directly in Simulator.
