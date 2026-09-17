import type { AIDetectionResult } from './AIDetectionProvider.js';
export async function detectText(document: string): Promise<AIDetectionResult> {
  if (!process.env.GPTZERO_API_KEY) throw new Error('Text provider is not configured');
  const response = await fetch('https://api.gptzero.me/v2/predict/text', {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-key': process.env.GPTZERO_API_KEY },
    body: JSON.stringify({ document }), signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) throw new Error('Text provider failed');
  const data = await response.json() as { documents?: { class_probabilities?: { ai?: number }; completely_generated_prob?: number }[] };
  const documentResult = data.documents?.[0];
  const probability = documentResult?.class_probabilities?.ai ?? documentResult?.completely_generated_prob;
  if (typeof probability !== 'number' || !Number.isFinite(probability) || probability < 0 || probability > 1) throw new Error('Invalid text result');
  return { aiProbability: probability, providerName: 'GPTZero' };
}
