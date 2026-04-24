# ACM-Automated-Car-Management-

ACM is an **agentic vehicle intelligence system** that transforms driving data into real-time insights about: 

-vehicle maintenence health
-fuel cost optimization
-driving behavior analysis
-Voice powered car copilot

Acts as **Dual-agent system** that continuously analyzes driving behavior and external fuel market conditions to reduce vehicle cost, prevent maintenance, and oimprove driving efficiency

Maintenance Agent analyzes driving behavior and servicehistory to predict and adjust maintenance schedules dynamically. 

## Inputs
-Odometer reading 
-vehicle type & fuel type 
-service history logs
-last service dates & mileage
-iPhone driving telemetry

## Outputs 
-Adjusted maintenance intervals 
-accelerated wear alerts
-saving projections vs average user behavior

# System Architecture
## iOS App
Responsible for: 
- Location tracking 
- Vehicle setup
- Service log input
- UI rendering 
- Offline caching 
- Trip detection 

## Backend 
-External API integration (Tiny Fish)
-Operating layer, trip telemetry processing (Express)
-Voice interface layer (Vapi)

# Core Backend Services
### Telemetry Ingestion Service
Processes raw iPhone data into structured driving insights.


### Maintenance Agent Service
Computes dynamic wear estimates 

# Key Features

##Trip Intelligence
-real-time driving behavior analysis
-route clustering 
-post-trip breakdowns

## Fuel Optimization 
-cheapest nearby stations
-commute cost forecasting
-price trend alerts via data

## Voice Copilot
-fuel recommendations
-maintenance explainations
-summaries of vehicle health

# Infrastructure

- **AWS** → backend hosting, jobs, secrets
- **Redis** → real-time memory + caching
- **Tinyfish** → live fuel & web intelligence
- **Vapi** → voice AI copilot layer
- **OpenAI / model API** → reasoning engine