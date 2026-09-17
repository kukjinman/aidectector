export type MediaType = "image" | "video" | "text";

export type ResultLabel = "likely_real" | "uncertain" | "likely_ai";

export type ErrorCode =
  | "INVALID_URL"
  | "PRIVATE_OR_UNAVAILABLE"
  | "MEDIA_TOO_LARGE"
  | "UNSUPPORTED_MEDIA_TYPE"
  | "PROVIDER_ERROR"
  | "RATE_LIMITED";

export interface AnalyzeSuccessResponse {
  status: "ok";
  aiProbability: number;
  label: ResultLabel;
  mediaType: MediaType;
  thumbnailUrl: string;
  provider: string;
  analyzedAt: string;
}

export interface AnalyzeErrorResponse {
  status: "error";
  code: ErrorCode;
  message: string;
}

export type AnalyzeResponse = AnalyzeSuccessResponse | AnalyzeErrorResponse;
