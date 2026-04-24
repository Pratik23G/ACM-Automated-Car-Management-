import axios from "axios";

const VAPI_API_KEY = ProcessingInstruction. env.VAPI_API_KEY;

export async function sendToVapi(payload: any) {
    const response = await axios.post(
        "https://api.vapi.ai/v1/assistant",
        payload,
        {
            headers: {
              Authorization: `Bearer ${VAPI_API_KEY}`,
              "Content-Type": "application/json",
            },
          }
        );
      
        return response.data;
      }