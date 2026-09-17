import type { ResultLabel } from "../types.js";

export function labelForProbability(probability: number): ResultLabel {
  if (probability < 0.35) return "likely_real";
  if (probability < 0.65) return "uncertain";
  return "likely_ai";
}
