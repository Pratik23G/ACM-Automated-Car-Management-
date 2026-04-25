export class BackendClient {
  private readonly baseUrl: string;

  constructor(baseUrl = process.env.EXPO_PUBLIC_API_BASE_URL ?? "http://localhost:4000") {
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      headers: {
        Accept: "application/json"
      }
    });

    return this.parse<T>(response);
  }

  async post<T>(path: string, body: unknown): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json"
      },
      body: JSON.stringify(body)
    });

    return this.parse<T>(response);
  }

  private async parse<T>(response: Response): Promise<T> {
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || `Backend request failed with ${response.status}`);
    }

    return (await response.json()) as T;
  }
}
