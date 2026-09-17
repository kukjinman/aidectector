export interface AIDetectionResult {
  /** Normalized probability in [0, 1] that the media is AI-generated. */
  aiProbability: number;
  providerName: string;
}

export interface AIDetectionProvider {
  readonly name: string;
  detect(imageBuffer: Buffer, contentType: string): Promise<AIDetectionResult>;
}
