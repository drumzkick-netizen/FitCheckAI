export type PhotoPurpose =
  | "outfit"
  | "dating"
  | "social"
  | "professional"
  | "compare"
  | "improve_fit";

export interface AnalyzePhotoRequestBody {
  imageBase64: string;
  purpose: PhotoPurpose;
}

export interface AnalysisSubscores {
  composition: number;
  lighting: number;
  presentation: number;
  purposeFit: number;
}

export interface AnalysisDebug {
  /** Short summary of key visible facts (internal QA only). */
  visibleFactsSummary?: Record<string, unknown> | null;
  /** Evaluable state such as "unevaluable" | "limited_but_usable" | "clearly_evaluable". */
  evaluability?: string | null;
  /** True when visible-facts parsing failed and a degraded fallback path was used. */
  visibleFactsFromFallback?: boolean;
  /** Optional counts for internal QA. */
  strengthsCount?: number;
  improvementsCount?: number;
  suggestionsCount?: number;
}

export type ValidationReason =
  | "no_person_detected"
  | "outfit_not_visible"
  | "image_not_relevant"
  | "framing_too_unclear";

export interface AnalysisResponse {
  isValid: boolean;
  validationMessage: string | null;
  reason: ValidationReason | null;
  score: number | null;
  subscores: AnalysisSubscores | null;
  strengths: string[];
  improvements: string[];
  suggestions: string[];
  /** Optional one-sentence explanation of the score (e.g. from subscores). Safe to omit for existing clients. */
  scoreExplanation?: string | null;
  /** Image-specific tips for better analysis (e.g. lighting/framing only when relevant). Omit or empty for existing clients. */
  analysisTips?: string[];
  /** When purpose is improve_fit: 3–5 actionable improvement suggestions. Omit otherwise. */
  improvementSuggestions?: string[];
  /** Optional internal-only debug summary to support QA. May be omitted; clients should ignore when not needed. */
  debug?: AnalysisDebug;
}

const VALID_PURPOSES: PhotoPurpose[] = [
  "outfit",
  "dating",
  "social",
  "professional",
  "compare",
  "improve_fit",
];

export function isPhotoPurpose(value: unknown): value is PhotoPurpose {
  return typeof value === "string" && VALID_PURPOSES.includes(value as PhotoPurpose);
}

const VALID_REASONS: ValidationReason[] = [
  "no_person_detected",
  "outfit_not_visible",
  "image_not_relevant",
  "framing_too_unclear",
];

export function isValidationReason(value: unknown): value is ValidationReason {
  return typeof value === "string" && VALID_REASONS.includes(value as ValidationReason);
}
