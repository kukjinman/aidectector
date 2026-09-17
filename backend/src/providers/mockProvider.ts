import { createHash } from "node:crypto";
import type { AIDetectionProvider, AIDetectionResult } from "./AIDetectionProvider.js";

/**
 * No external calls, no API key. Derives a deterministic pseudo-probability
 * from the image bytes so the same media always yields the same result,
 * which is convenient for local development, demos, and tests. Replace
 * with SightengineProvider (or another real adapter) before shipping.
 */
export class MockAIDetectionProvider implements AIDetectionProvider {
  readonly name = "mock";

  async detect(imageBuffer: Buffer): Promise<AIDetectionResult> {
    const hash = createHash("sha256").update(imageBuffer).digest();
    const probability = hash.readUInt16BE(0) / 0xffff;
    return { aiProbability: probability, providerName: this.name };
  }
}
