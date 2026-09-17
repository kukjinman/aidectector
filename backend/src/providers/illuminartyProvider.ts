import type { AIDetectionProvider, AIDetectionResult } from "./AIDetectionProvider.js";

interface IlluminartyResponse {
  status?: string;
  data?: { probability?: number };
}

export class IlluminartyError extends Error {
  constructor(readonly reason: string, readonly httpStatus: number, readonly responseBytes: number) {
    super(reason);
  }
}

/**
 * Adapter for Illuminarty's AI-generated image detection (https://illuminarty.ai).
 * Enable with AI_PROVIDER=illuminarty and ILLUMINARTY_API_KEY set. Images only —
 * Illuminarty's public API has no video endpoint, so video buffers are rejected.
 */
export class IlluminartyProvider implements AIDetectionProvider {
  readonly name = "illuminarty";

  constructor(private readonly apiKey: string) {}

  async detect(imageBuffer: Buffer, contentType: string): Promise<AIDetectionResult> {
    if (contentType.startsWith("video/")) {
      throw new Error("Illuminarty does not support video analysis");
    }

    const form = new FormData();
    form.append("file", new Blob([new Uint8Array(imageBuffer)], { type: contentType }), "media");

    const res = await fetch("https://api.illuminarty.ai/v1/image/classify", {
      method: "POST",
      headers: { 'X-API-Key': this.apiKey },
      body: form,
      signal: AbortSignal.timeout(30_000),
    });

    const response = await res.text();
    const bytes = Buffer.byteLength(response);
    if (!res.ok) throw new IlluminartyError('upstream_http_error', res.status, bytes);
    if (!response.trim()) throw new IlluminartyError('upstream_empty_response', res.status, bytes);
    let json: IlluminartyResponse;
    try { json = JSON.parse(response); }
    catch { throw new IlluminartyError('upstream_invalid_json', res.status, bytes); }
    if (!json || typeof json !== 'object') throw new IlluminartyError('upstream_invalid_shape', res.status, bytes);
    if (json.status !== 'success') throw new IlluminartyError('upstream_unsuccessful', res.status, bytes);
    const probability = json.data?.probability;
    const valid = typeof probability === "number" && Number.isFinite(probability) && probability >= 0 && probability <= 1;
    if (!valid) {
      throw new IlluminartyError('upstream_invalid_shape', res.status, bytes);
    }

    return { aiProbability: probability, providerName: this.name };
  }
}
