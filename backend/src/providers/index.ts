import type { AIDetectionProvider } from "./AIDetectionProvider.js";
import { MockAIDetectionProvider } from "./mockProvider.js";
import { SightengineProvider } from "./sightengineProvider.js";
import { IlluminartyProvider } from "./illuminartyProvider.js";

export function createProvider(env: NodeJS.ProcessEnv = process.env): AIDetectionProvider {
  const providerName = env.AI_PROVIDER ?? "mock";

  if (providerName === "sightengine") {
    const apiUser = env.SIGHTENGINE_API_USER;
    const apiSecret = env.SIGHTENGINE_API_SECRET;
    if (!apiUser || !apiSecret) {
      throw new Error(
        "SIGHTENGINE_API_USER and SIGHTENGINE_API_SECRET must be set when AI_PROVIDER=sightengine",
      );
    }
    return new SightengineProvider(apiUser, apiSecret);
  }

  if (providerName === "illuminarty") {
    const apiKey = env.ILLUMINARTY_API_KEY;
    if (!apiKey) {
      throw new Error("ILLUMINARTY_API_KEY must be set when AI_PROVIDER=illuminarty");
    }
    return new IlluminartyProvider(apiKey);
  }

  if (providerName !== "mock" || env.NODE_ENV === "production") throw new Error("Production requires a real AI provider");
  return new MockAIDetectionProvider();
}
