export function copilotPrompt(data: any) {
    return `
  You are a smart driving copilot.
  
  Combine:
  - maintenance insights
  - fuel intelligence
  
  Give a short spoken summary:
  - biggest risk
  - biggest savings opportunity
  - next action
  
  Keep it under 20 seconds spoken.
  `;
  }