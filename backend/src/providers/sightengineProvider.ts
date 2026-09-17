import type { AIDetectionProvider, AIDetectionResult } from "./AIDetectionProvider.js";

interface SightengineResponse {
  status?: string;
  data?: { frames?: { type?: { ai_generated?: number } }[] };
  type?: {
    ai_generated?: number;
  };
}

/**
 * Adapter for Sightengine's "genai" model (https://sightengine.com/docs).
 * Enable with AI_PROVIDER=sightengine and the two env vars below set.
 */
export class SightengineProvider implements AIDetectionProvider {
  readonly name = "sightengine";

  constructor(
    private readonly apiUser: string,
    private readonly apiSecret: string,
  ) {}

  async detect(imageBuffer: Buffer, contentType: string): Promise<AIDetectionResult> {
    const form = new FormData();
    form.append("media", new Blob([new Uint8Array(imageBuffer)], { type: contentType }), "media");
    form.append("models", "genai");
    form.append("api_user", this.apiUser);
    form.append("api_secret", this.apiSecret);

    const isVideo = contentType.startsWith("video/");
    if (isVideo) form.append("interval", "5");
    const endpoint = isVideo ? "video/check-sync.json" : "check.json";
    const res = await fetch(`https://api.sightengine.com/1.0/${endpoint}`, {
      method: "POST",
      body: form,
      signal: AbortSignal.timeout(90_000),
    });

    if (!res.ok) {
      throw new Error(`Sightengine request failed with HTTP ${res.status}`);
    }

    const json = (await res.json()) as SightengineResponse;
    const scores = json.data?.frames?.map(frame => frame.type?.ai_generated) ?? [];
    const valid = (n: unknown): n is number => typeof n === "number" && Number.isFinite(n) && n >= 0 && n <= 1;
    const probability = isVideo && scores.length && scores.every(valid)
      ? scores.reduce((sum, score) => sum + score, 0) / scores.length : json.type?.ai_generated;
    if (json.status !== "success" || !valid(probability)) {
      throw new Error("Unexpected Sightengine response shape");
    }

    return { aiProbability: probability, providerName: this.name };
  }
}
