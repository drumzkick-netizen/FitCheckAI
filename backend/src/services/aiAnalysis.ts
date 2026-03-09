import OpenAI from "openai";
import crypto from "crypto";
import { InvalidAIResponseError, OpenAIServiceError } from "../errors";
import {
  AnalysisResponse,
  AnalysisSubscores,
  AnalysisDebug,
  PhotoPurpose,
  ValidationReason,
  isValidationReason,
} from "../types";
import { resizeAndCompressImage } from "./imageUtils";

const LOG_PREFIX = "[analyze-photo]";

const ANALYSIS_DEBUG_ENABLED =
  process.env.FITCHECK_DEBUG_ANALYSIS === "1" ||
  process.env.FITCHECK_DEBUG_ANALYSIS === "true";

/** Temporary debug: force gpt-4o-mini for reliability testing. */
function getModel(): string {
  return "gpt-4o-mini";
}

/** Clamp to 0–10 and round to one decimal place. All scores use this for consistency. */
function roundToOneDecimal(value: number): number {
  const clamped = Math.min(10, Math.max(0, value));
  return Math.round(clamped * 10) / 10;
}

/** Generate realistic subscores from overall score when API omits them. */
function subscoresFromScore(score: number): AnalysisSubscores {
  const s = roundToOneDecimal(score);
  return {
    composition: roundToOneDecimal(s - 0.2),
    lighting: roundToOneDecimal(s + 0.2),
    presentation: roundToOneDecimal(s - 0.1),
    purposeFit: roundToOneDecimal(s + 0.1),
  };
}

const FALLBACK_MOCK_SCORE = 7.5;

function getFallbackMockResult(): AnalysisResponse {
  console.log("Falling back to mock analysis: defaulting to valid with mock score");
  const score = FALLBACK_MOCK_SCORE;
  const subscores = subscoresFromScore(score);
  return {
    isValid: true,
    validationMessage: null,
    reason: null,
    score,
    subscores,
    strengths: ["Photo received for analysis", "Ready for feedback when AI is available"],
    improvements: ["Connect a valid OpenAI API key for full analysis"],
    suggestions: ["Check your API key in Settings if you expect AI scoring"],
    analysisTips: ["Connect a valid OpenAI API key for full analysis tips."],
    improvementSuggestions: [],
    scoreExplanation: subscores ? deriveScoreExplanation(subscores) : undefined,
  };
}

type EvaluabilityState = "unevaluable" | "limited_but_usable" | "clearly_evaluable";

interface AnalysisDebugInfo {
  purpose: PhotoPurpose;
  fingerprint?: string;
  cacheHitType?: "none" | "exact" | "near_duplicate";
  cacheAnchorSimilarity?: number | null;

  evaluability?: EvaluabilityState;
  visibleFactsSummary?: Partial<VisibleFacts>;

  rawModelScore?: unknown;
  normalizedScore?: number | null;
  derivedScore?: number | null;
  derivedSubscores?: AnalysisSubscores | null;

  rawGroundedStrengths?: string[];
  rawGroundedImprovements?: string[];
  rawGroundedSuggestions?: string[];

  usedFallbackStrengths?: boolean;
  usedFallbackImprovements?: boolean;
  usedFallbackSuggestions?: boolean;

  phase1Rejected?: boolean;
  phase1Reason?: ValidationReason | null;

  phase2ValidatorRejected?: boolean;
  phase2ValidatorReason?: ValidationReason | null;

  regenerationAttempted?: boolean;
  regenerationSucceeded?: boolean;

  fallbackMockUsed?: boolean;

  finalStrengths?: string[];
  finalImprovements?: string[];
  finalSuggestions?: string[];
  finalAnalysisTips?: string[];
  finalScore?: number | null;
  visibleFactsFromFallback?: boolean;
}

function logDebugSnapshot(stage: string, info: AnalysisDebugInfo | null | undefined): void {
  if (!ANALYSIS_DEBUG_ENABLED || !info) return;
  try {
    console.log(
      `${LOG_PREFIX} debug snapshot — ${stage}`,
      JSON.stringify(info, null, 2)
    );
  } catch (err) {
    console.log(`${LOG_PREFIX} debug snapshot logging failed`, {
      stage,
      message: err instanceof Error ? err.message : String(err),
    });
  }
}

// --- Cheap validation (phase 1): low-detail image, minimal prompt, ~80 tokens out ---
const VALIDATION_SYSTEM =
  `Reply with only a JSON object: { "isValid": boolean, "validationMessage": string | null, "reason": string | null }.
Set isValid to false only if the image is clearly: no person (landscape, food, pet, object, screenshot, meme). Use reason: "no_person_detected" | "outfit_not_visible" | "image_not_relevant" | "framing_too_unclear". If a person is visible or unsure, set isValid true, validationMessage and reason null. No other text.`;

const VALIDATION_USER = "Is there a clearly visible person in this image suitable for outfit/photo feedback? Reply with the JSON only.";

// --- Full analysis (phase 2): outfit-first evaluation ---

const REASONING_PROCESS = `
Before scoring, follow this order. The score reflects OUTFIT quality; photo quality has minimal weight (5%).

1) IDENTIFY VISIBLE CLOTHING
   List visible pieces: tops, outerwear, bottoms, shoes, accessories. Reference these in feedback.

2) EVALUATE FIT AND PROPORTION (40% + 20% of score)
   Fit: how garments sit—shoulders, waist, length. Proportion/silhouette: balance between top and bottom, layering, overall shape. This is the primary driver of the score.

3) EVALUATE COLOR COORDINATION (25%)
   How colors work together across the outfit. Palette balance.

4) EVALUATE STYLE COHESION AND OCCASION (10%)
   How well the look holds together and fits the chosen purpose.

5) PHOTO CLARITY (5% only)
   Only whether the outfit is visible enough to evaluate. If the outfit is visible, score 7.0 or higher. Do NOT penalize for background, lighting, or framing. Do not let photo quality drag down the overall score for a good outfit.
`;

const EVIDENCE_BASED_FIT_RULES = `
EVIDENCE-BASED FIT AND IMPROVEMENTS — CRITICAL:
- Base ALL fit and "Could Improve" feedback ONLY on what is clearly visible in the image. Do not invent or assume.
- Do NOT suggest a garment should be looser, tighter, or more tailored if that contradicts what is visible (e.g. do NOT say "the shirt could be looser" when the shirt is already visibly oversized).
- For fit: either (a) describe what you actually see (e.g. "The shirt reads slightly oversized, which softens the silhouette"), or (b) if fit is hard to judge from angle/lighting, say so and avoid a strong directional recommendation (e.g. "Fit is harder to judge from this angle—no strong fit change needed").
- "Could Improve" must reflect actual weaknesses visible in this photo, not default or generic style advice. If the image is strong, give fewer or no improvements; do not pad with filler.
- Never give advice that contradicts the visible garment (e.g. "try a looser fit" when the item is already loose). Stay grounded in observable details only.
`;

const VISIBILITY_GROUNDING_RULES = `
VISIBILITY — ONLY CRITIQUE WHAT IS CLEARLY VISIBLE. CRITICAL:
- Do NOT comment on, suggest, or critique any clothing area or garment detail that is NOT clearly visible in the image. Do not infer or assume hidden details.
- Do NOT recommend hemming pants, shortening pants, adjusting pant break, or any pant-length or leg-hem advice UNLESS the full leg and hem (or at least the ankle/break) are clearly visible in the photo. If pants are cropped out, say nothing about pant length or use: "Pant length is not clearly visible enough to judge."
- Do NOT recommend or comment on footwear, shoe choice, or socks UNLESS feet/shoes are clearly visible in the image.
- Do NOT recommend hemming sleeves, tailoring cuffs, or adjusting sleeve length UNLESS the sleeve ends or cuffs are clearly visible.
- Do NOT suggest altering hems, cuffs, or garment edges that are cropped out or not visible. Prefer conservative feedback over speculative advice.
- If an outfit area is cropped out, obscured, or unclear: either stay silent about that area, or use explicit hedging (e.g. "Sleeve length is not clearly visible enough to judge", "Footwear is not visible in this frame").
- Only critique specific garment zones when they are visible enough in the image to support the comment. When in doubt, omit the point.
`;

const GROUNDED_STYLING_SUGGESTIONS_RULES = `
PART 1 — IDENTIFY VISIBLE STYLING FACTS FIRST
- Before generating strengths, improvements, suggestions, or improvementSuggestions, first identify key visible styling facts such as:
  - whether the top is tucked or untucked
  - whether bracelets, watches, necklaces, rings, belts, bags, or other accessories are visible
  - whether shoes/footwear are visible
  - whether earrings or the ear area are visible
  - whether the waistband/waistline styling is visible
  - whether garment edges like hems, cuffs, or sleeves are clearly visible
- Treat these visible facts as hard constraints for later feedback and suggestions. Subsequent recommendations must not contradict what you have already observed.

PART 2 — DO NOT RECOMMEND WHAT IS ALREADY PRESENT
- Do NOT recommend a styling action if that detail is already clearly and visibly present in the image.
- Examples: do not suggest tucking in a top that is already tucked; do not suggest bracelets or a watch if bracelets or a watch are already visible; do not suggest "add accessories" generically if accessories are already present unless the recommendation is specifically different and clearly justified by what you see.
- When analysisContext.visibleFacts.top_tucked is true, do NOT suggest tucking, re-tucking, or "enhancing waist definition by tucking" the top. Treat an already tucked top as an existing styling choice, not an improvement opportunity.
- If a detail is already present and working well, prefer to acknowledge it as a strength rather than recommending it again as an improvement.

PART 3 — DO NOT RECOMMEND HIDDEN OR UNCLEAR DETAILS
- Do NOT recommend changes to areas that are hidden, cropped out, or not clearly visible.
- Examples:
  - do not suggest earrings unless the ear area is clearly visible and the recommendation is visually justified
  - do not suggest shoe changes unless footwear is clearly visible
  - do not suggest hemming or pant-break changes unless the lower pant edge or hem is visible
  - do not suggest belt or waistband changes unless the waist area is clearly visible
  - do not suggest sleeve/cuff changes unless sleeves/cuffs are clearly visible
- If visibility is limited for a specific area, either stay silent about that area OR use conservative wording such as "That area is not clearly visible enough to judge."

PART 4 — DO NOT FORCE WEAK SUGGESTIONS
- If the outfit already appears clean, coherent, and visually complete, it is acceptable to return fewer suggestions.
- Do NOT force weak or generic filler advice just to populate every section.
- It is acceptable to return 1 strong suggestion instead of 3 weak ones.
- It is acceptable to return no improvementSuggestions when there is no honest, evidence-based recommendation grounded in the image.
- Quality rule: prefer fewer, better suggestions over more generic ones.

PART 5 — SUGGESTION STYLE RULES
- All improvement suggestions must be grounded in visible evidence, specific when possible, conservative when uncertain, visually honest, and free from fake precision.
- Avoid generic "add accessories" filler unless a specific, visually justified accessory change is clearly supported by the image.
- Prefer observations about silhouette, balance and proportion, visible color coordination, and overall outfit completeness based on what is actually visible in the frame.
`;

const CONSERVATIVE_TAILORING_RULES = `
CONSERVATIVE TAILORING AND FIT ADVICE — BE VERY RESTRAINED:

PART 1 — DO NOT RECOMMEND MORE FITTED IF THE GARMENT ALREADY READS FITTED
- If a garment already appears close-fitting, body-skimming, silhouette-defining, structured through the torso, or clearly shaped at the waist, do NOT recommend making it more fitted.
- Examples: do not suggest a fitted tank top should be more fitted; do not suggest a slim button-up should be tighter if it already reads close to the body; do not suggest more waist definition if the waistline is already visually clear.

PART 2 — REQUIRE STRONG EVIDENCE BEFORE SUGGESTING TIGHTER FIT
- Only suggest a more fitted garment when ALL of the following are true:
  1) the garment clearly appears loose or boxy in a way that materially weakens the silhouette,
  2) that looseness is visually obvious from the image, and
  3) the relevant garment area is clearly visible.
- If any of these are unclear (fit ambiguous, crop/pose hides the area, fabric behavior is hard to interpret), do NOT recommend a tighter fit.

PART 3 — PREFER OBSERVATIONAL LANGUAGE OVER PRESCRIPTIVE TIGHTENING
- When discussing fit, prefer neutral, observational language such as:
  - "The top reads relaxed through the torso."
  - "The silhouette is softer than sharp."
  - "The cut leans easy rather than tailored."
- Avoid prescriptive tightening language like:
  - "It should be more fitted."
  - "Tighten the waist."
  - "Wear something tighter."
- Only recommend a fit change when it is clearly justified by strong visual evidence.

PART 4 — IF THE TOP ALREADY DEFINES THE WAIST, TREAT THAT AS A STRENGTH
- When a top already creates a clean waistline or flattering shape, treat that as a positive rather than a weakness.
- Better examples: "The fitted top creates a clear waistline."; "The top already gives the outfit a clean, streamlined shape."

PART 5 — DO NOT FORCE SILHOUETTE ADVICE
- If the silhouette already appears to be working well, do NOT invent silhouette-improvement advice just to fill a section.
- It is acceptable to return fewer suggestions instead of forcing weak fit advice when the overall silhouette reads strong and coherent.

- In general, avoid highly specific tailoring advice unless the visual evidence is extremely clear. Garment fit is often ambiguous in photos.
- Do NOT casually recommend: tighter fit, looser fit, more tailored waist, more fitted through the torso, or similar alteration-style advice. Such recommendations are often wrong when the garment already appears appropriately fitted.
- If garment fit is unclear due to pose, crop, fabric behavior, body angle, or image quality, do NOT give directional fit advice. Instead say something like "Fit is hard to judge precisely from this angle—avoid a strong tailoring recommendation."
- Prefer OBSERVATIONAL language over prescriptive tailoring advice. Describe how the fit reads visually; describe silhouette and proportion; describe whether the outfit reads relaxed, streamlined, boxy, sharp, oversized, or structured. Do not tell the user to alter the garment unless it is truly obvious.
- BAD examples (do not say): "The shirt should be more fitted", "The shirt should be looser", "Tailor the waist more", "This top would benefit from a looser fit".
- BETTER examples: "The shirt already reads as close-fitting", "The silhouette is streamlined", "The top reads slightly relaxed, which softens the overall shape", "Fit is hard to judge precisely from this angle."
- Prioritize styling, silhouette, and outfit balance over tailoring advice. If an improvement is needed, suggest styling changes (e.g. tuck, layer, proportion, color, accessory) before any alteration or fit-change advice. Only recommend fit changes when truly obvious from the image.
`;

const EVALUATION_PRIORITIES = `
SCORING PRIORITIES (outfit over photo):
1. Fit/tailoring of clothing (40%): How well garments fit—shoulders, waist, length, how pieces sit on the body.
2. Color coordination and palette balance (25%): How colors work together across the outfit.
3. Proportion and silhouette (20%): Balance between top and bottom, layering, overall shape.
4. Style cohesion and occasion appropriateness (10%): How well the look holds together and fits the purpose.
5. Photo clarity and framing (5%): Only whether the outfit is visible enough to evaluate. If the outfit is visible, score this 7.0 or higher. Do NOT penalize for background, lighting, or framing unless the outfit cannot be seen clearly. The score must reflect the OUTFIT itself, not the quality of the photo.`;

const CORE_PHILOSOPHY = `
CORE: The score reflects OUTFIT QUALITY, not photo quality. Do NOT heavily penalize a good outfit for background, lighting, or framing. Background matters only if the outfit is not visible. Do not judge personal attractiveness. Strong outfits score well even with busy backgrounds or imperfect lighting. Only mention photo/lighting/background in feedback if the outfit truly cannot be analyzed.`;

function getPurposeFitGuidance(purpose: PhotoPurpose): string {
  if (purpose === "dating") {
    return `
PURPOSE-FIT (dating): How well the outfit works for a dating context (warmth, approachability). Face visibility: mention only when genuinely relevant, as a soft suggestion, not a requirement. Do not lower scores for missing face if the outfit is strong.`;
  }
  if (purpose === "social" || purpose === "professional") {
    return `
PURPOSE-FIT (${purpose}): How well the outfit fits the purpose. Mention face or setting only when relevant; outfit-first.`;
  }
  return "";
}

const IMPROVE_FIT_SYSTEM_PROMPT = `
You are an outfit improvement assistant. (1) Validate: set isValid true unless the image clearly has no person (landscape, food, pet, object, meme). (2) If valid, look at the outfit in the image and output up to 3 concise, specific improvement suggestions. Prefer giving fewer suggestions over speculative ones when the outfit is already working well.

VISIBILITY — only suggest changes for what is clearly visible:
- Do NOT suggest hemming pants, shortening pants, pant break, or any pant-length advice unless the leg/hem is clearly visible. Do not mention footwear or shoe choice unless feet/shoes are visible. Do not suggest hemming sleeves or tailoring cuffs unless sleeve ends are visible.
- Ground every suggestion in a garment or detail that is clearly visible in the image. If an area is cropped out or not visible, do not make a suggestion about it.

GROUNDED STYLING FACTS AND SUGGESTIONS:
- First, identify key visible styling facts: whether the top is tucked or untucked; whether bracelets, watches, necklaces, rings, bags, or other accessories are visible; whether shoes/footwear are visible; whether earrings or the ear area are clearly visible; whether the waistband/waistline styling is visible.
- Do NOT recommend a styling action that is already clearly present (e.g. do NOT suggest tucking in a top that is already tucked; do NOT suggest bracelets if bracelets or a watch are already visible).
- Do NOT suggest earrings unless the ears or ear area are clearly visible and the idea is visually justified. Do NOT suggest belt or waistband changes unless the waist area is clearly visible. Do NOT suggest shoe changes unless footwear is clearly visible.
- Avoid hidden or speculative details. If a styling area is cropped out, covered, or unclear, either stay silent or briefly acknowledge that it is not visible enough to judge.
- Improvement suggestions must be based on visible evidence, not generic fashion filler. Avoid vague advice like "add accessories" without tying it to a clearly visible area.
- If a styling area is already working well, it is acceptable to leave it as-is rather than forcing an improvement.
- When uncertain, default to conservative, visually honest feedback instead of precise-sounding but speculative recommendations.
  In particular, do NOT suggest that a top should be "more fitted" or "tighter" when it already appears close-fitting, body-skimming, or clearly defining the waistline.

RULES FOR improvementSuggestions:
- Reference clothing visible in the image when possible (e.g. "The overshirt could be worn open to break up the block of color", "Tucking the hem of the tee would sharpen the waistline") and ensure the change you suggest is not already clearly present.
- Avoid generic advice. Do not say things like "consider balance", "try adding an accessory", or "check that colors work" without naming what you see (e.g. which garment, which color, which area).
- Focus only on practical outfit adjustments for VISIBLE elements: fit adjustments (tuck, cuff, how something is worn), color balance (between visible pieces), layering (order, opening a layer), accessories (belt, watch, bag, jewelry) that build on what is already there. Mention footwear only if shoes are clearly visible. Do not suggest alterations (hem, tailor, shorten) unless that part of the garment is clearly visible.
- Do not give camera, lighting, framing, or photo-quality advice. Only outfit and styling.
- Output up to 3 suggestions. Each suggestion one short sentence. It is acceptable to return fewer than 3 suggestions, or even none, when there is no honest, evidence-based recommendation. Ground every suggestion in what is visible (specific garment or detail).

Output single JSON only. No markdown.
{ "isValid": bool, "validationMessage": null|string, "reason": null|"no_person_detected"|"outfit_not_visible"|"image_not_relevant"|"framing_too_unclear", "improvementSuggestions": ["suggestion 1", "suggestion 2", "suggestion 3"] }
`;

function getFullAnalysisSystemPrompt(purpose: PhotoPurpose): string {
  if (purpose === "improve_fit") {
    return IMPROVE_FIT_SYSTEM_PROMPT;
  }
  const focus: Record<Exclude<PhotoPurpose, "improve_fit">, string> = {
    outfit: "Fit, proportions, color, layering, silhouette, cohesion.",
    dating: "How well the outfit works for a dating context; warmth and approachability of the look.",
    social: "How well the outfit works for social sharing; impact and cohesion of the look.",
    professional: "How well the outfit works for a professional context; polish and cohesion.",
    compare: "Outfit clarity and presentation for comparison.",
  };
  const purposeBlock = getPurposeFitGuidance(purpose);

  return `You are an outfit evaluation assistant. Your primary goal is to evaluate the clothing and styling of the person in the image. (1) Validate: isValid true unless clearly no person (landscape, food, pet, object, meme). (2) If valid, follow the reasoning process below, then use the PROVIDED numeric subscores and overall score to give feedback. Do NOT change or re-score these numbers. All feedback and suggestions must be grounded in the visible facts and must respect the visibility and styling rules below.
${REASONING_PROCESS}
${VISIBILITY_GROUNDING_RULES}
${GROUNDED_STYLING_SUGGESTIONS_RULES}
${EVIDENCE_BASED_FIT_RULES}
${CONSERVATIVE_TAILORING_RULES}
${EVALUATION_PRIORITIES}
${CORE_PHILOSOPHY}

Purpose: ${purpose}. ${focus[purpose as Exclude<PhotoPurpose, "improve_fit">]}
${purposeBlock}

SUBScores (one decimal each, 0.0–10.0). Weight in overall: composition 60%, presentation 25%, purposeFit 10%, lighting 5%.
- composition: Fit/tailoring of clothing (how garments fit—shoulders, waist, length) AND proportion/silhouette (balance, layering, overall shape). Primary driver of score.
- presentation: Color coordination and palette balance across the outfit.
- purposeFit: Overall style cohesion and how well the look fits the chosen occasion/purpose.
- lighting: Photo clarity and whether the outfit is visible enough to evaluate. If the outfit is clearly visible, score 7.0 or higher. Do NOT penalize for background, lighting, or framing. Only lower this if the outfit cannot be seen clearly.

FEEDBACK BEHAVIOR — outfit-first. Reference specific garments. Do not penalize or criticize photo quality unless the outfit truly cannot be analyzed.

- What Works (output as "strengths"): Highlight outfit elements that work well—only for garments/details clearly visible (e.g. "Jacket fit is clean at the shoulders", "Shirt and trouser color balance works well"). Mention footwear or shoes only if feet/shoes are visible; otherwise omit. No generic praise. Do not mention lighting or background unless the outfit is hard to see.
- Could Improve (output as "improvements"): Only clothing-related issues you can clearly see in the image (fit, color, proportion, silhouette). Do NOT suggest hemming, shortening, or adjusting pants/sleeves/cuffs/footwear unless those areas are clearly visible. Do NOT mention lighting, background, or framing unless the outfit cannot be seen clearly. 0–3 points. Prefer observational language and avoid forcing weak issues when the outfit already reads clean and complete.
- Suggestions: 0–3 concrete outfit suggestions referencing only visible clothing (tuck, layer, color, accessory). It is acceptable to return fewer than 3 suggestions (including none) when the outfit already looks coherent and complete or when no strong, evidence-based changes are apparent. Mention footwear only if shoes are visible. Do not suggest hemming, tailoring hems/cuffs, or changing shoe choice unless those elements are clearly visible in the photo. No generic camera advice.
- analysisTips (output as "analysisTips"): Only include tips here if the outfit truly cannot be analyzed (e.g. too dark, cropped so outfit is missing). If the outfit is visible and evaluable, output an empty array []. Do NOT give generic tips like "use better lighting" or "avoid cluttered background" when the outfit was clearly evaluable.

Do not repeat the same point across sections. Tone: concise, fit-check style. Score and feedback must reflect the outfit, not the photo.

Output single JSON only. No markdown.
{ "isValid": bool, "validationMessage": null|string, "reason": null|"no_person_detected"|"outfit_not_visible"|"image_not_relevant"|"framing_too_unclear", "score": number|null, "subscores": { "composition", "lighting", "presentation", "purposeFit" }|null, "strengths": [], "improvements": [], "suggestions": [], "analysisTips": [] }`;
}

function clampSubscore(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  if (Number.isNaN(n)) return 7;
  return roundToOneDecimal(n);
}

function parseSubscores(parsed: Record<string, unknown>, fallbackScore: number): AnalysisSubscores {
  const raw = parsed.subscores;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return subscoresFromScore(fallbackScore);
  }
  const obj = raw as Record<string, unknown>;
  return {
    composition: clampSubscore(obj.composition),
    lighting: clampSubscore(obj.lighting),
    presentation: clampSubscore(obj.presentation),
    purposeFit: clampSubscore(obj.purposeFit),
  };
}

// --- Stage 1: Visible facts extraction ---

type BodyCropType = "full_body" | "upper_body" | "mid_body" | "close_crop" | "unclear";
type FitDescriptor = "fitted" | "relaxed" | "oversized" | "unclear";
type VisibilityTriState = "visible" | "hidden" | "unclear";

interface VisibleFacts {
  person_visible: boolean;
  body_crop_type: BodyCropType;
  top_type: string | null;
  top_fit: FitDescriptor;
  top_tucked: boolean | null;
  outerwear_visible: boolean | null;
  bottom_type: string | null;
  bottom_fit: FitDescriptor;
  waist_visible: boolean | null;
  waist_definition_visible: boolean | null;
  shoe_visible: boolean | null;
  pant_hem_visible: boolean | null;
  sleeve_visible: boolean | null;
  cuff_visible: boolean | null;
  ear_visibility: VisibilityTriState;
  hair_visibility: string | null;
  necklace_visible: boolean | null;
  bracelets_visible: boolean | null;
  watch_visible: boolean | null;
  ring_visible: boolean | null;
  belt_visible: boolean | null;
  accessory_summary: string | null;
  color_palette_summary: string | null;
  silhouette_read: string | null;
  background_simple_or_busy: "simple" | "busy" | "unclear";
  lighting_quality: string | null;
  outfit_visibility_quality: string | null;
}

const DEFAULT_VISIBLE_FACTS: VisibleFacts = {
  person_visible: true,
  body_crop_type: "unclear",
  top_type: null,
  top_fit: "unclear",
  top_tucked: null,
  outerwear_visible: null,
  bottom_type: null,
  bottom_fit: "unclear",
  waist_visible: null,
  waist_definition_visible: null,
  shoe_visible: null,
  pant_hem_visible: null,
  sleeve_visible: null,
  cuff_visible: null,
  ear_visibility: "unclear",
  hair_visibility: null,
  necklace_visible: null,
  bracelets_visible: null,
  watch_visible: null,
  ring_visible: null,
  belt_visible: null,
  accessory_summary: null,
  color_palette_summary: null,
  silhouette_read: null,
  background_simple_or_busy: "unclear",
  lighting_quality: null,
  outfit_visibility_quality: null,
};

// --- Consistency cache: stabilize results for identical / near-duplicate photos ---

interface CachedAnalysisEntry {
  fingerprint: string;
  purpose: PhotoPurpose;
  visibleFacts: VisibleFacts;
  response: AnalysisResponse;
  lastUsedAt: number;
}

const ANALYSIS_CACHE = new Map<string, CachedAnalysisEntry>();
const ANALYSIS_CACHE_MAX_ENTRIES = 100;

function computeImageFingerprint(normalizedBase64: string): string {
  // Hash the compressed base64 (without data URL prefix) for stability across uploads.
  const base64 = normalizedBase64.startsWith("data:")
    ? normalizedBase64.substring(normalizedBase64.indexOf(",") + 1)
    : normalizedBase64;
  const hash = crypto.createHash("sha256");
  hash.update(base64);
  return hash.digest("hex").slice(0, 32);
}

function factsSimilarity(a: VisibleFacts, b: VisibleFacts): number {
  let matches = 0;
  let total = 0;

  function cmp<T>(av: T, bv: T) {
    total += 1;
    if (av === bv) matches += 1;
  }

  cmp(a.body_crop_type, b.body_crop_type);
  cmp(a.top_type, b.top_type);
  cmp(a.top_fit, b.top_fit);
  cmp(a.top_tucked, b.top_tucked);
  cmp(a.bottom_type, b.bottom_type);
  cmp(a.bottom_fit, b.bottom_fit);
  cmp(a.waist_visible, b.waist_visible);
  cmp(a.waist_definition_visible, b.waist_definition_visible);
  cmp(a.shoe_visible, b.shoe_visible);
  cmp(a.pant_hem_visible, b.pant_hem_visible);
  cmp(a.sleeve_visible, b.sleeve_visible);
  cmp(a.cuff_visible, b.cuff_visible);
  cmp(a.ear_visibility, b.ear_visibility);
  cmp(a.necklace_visible, b.necklace_visible);
  cmp(a.bracelets_visible, b.bracelets_visible);
  cmp(a.watch_visible, b.watch_visible);
  cmp(a.ring_visible, b.ring_visible);
  cmp(a.belt_visible, b.belt_visible);
  cmp(a.background_simple_or_busy, b.background_simple_or_busy);

  return total === 0 ? 0 : matches / total;
}

function findBestCachedMatch(
  purpose: PhotoPurpose,
  facts: VisibleFacts
): { entry: CachedAnalysisEntry; similarity: number } | null {
  let best: CachedAnalysisEntry | null = null;
  let bestSim = 0;
  const now = Date.now();

  for (const entry of ANALYSIS_CACHE.values()) {
    if (entry.purpose !== purpose) continue;
    const sim = factsSimilarity(facts, entry.visibleFacts);
    if (sim > bestSim) {
      bestSim = sim;
      best = entry;
    }
  }

  if (best && bestSim >= 0.95) {
    best.lastUsedAt = now;
    return { entry: best, similarity: bestSim };
  }

  return null;
}

function putCachedAnalysis(
  fingerprint: string,
  purpose: PhotoPurpose,
  visibleFacts: VisibleFacts,
  response: AnalysisResponse
): void {
  const now = Date.now();
  ANALYSIS_CACHE.set(fingerprint, {
    fingerprint,
    purpose,
    visibleFacts,
    response,
    lastUsedAt: now,
  });

  if (ANALYSIS_CACHE.size > ANALYSIS_CACHE_MAX_ENTRIES) {
    // Evict least-recently used entry.
    let oldestKey: string | null = null;
    let oldestTime = Infinity;
    for (const [key, entry] of ANALYSIS_CACHE.entries()) {
      if (entry.lastUsedAt < oldestTime) {
        oldestTime = entry.lastUsedAt;
        oldestKey = key;
      }
    }
    if (oldestKey != null) {
      ANALYSIS_CACHE.delete(oldestKey);
    }
  }
}

const VISIBLE_FACTS_SYSTEM_PROMPT = `
You are a vision helper for a style app. In this step you ONLY output one compact JSON object describing what is clearly visible in the image. Do NOT give style advice, opinions, or extra text.

Rules:
- Reply with ONE JSON object only. No markdown, no explanations, no commentary.
- Use the exact keys and types listed below.
- When something is not clearly visible, use "unclear" for enums or null for strings.
- For all free-text string fields, keep values extremely short: ideally 1–3 simple words, no commas, no full sentences. If you would need a longer phrase, use null instead.
 - For *_visible boolean fields (shoe_visible, belt_visible, bracelets_visible, watch_visible, necklace_visible, ring_visible, waist_visible, waist_definition_visible), follow this rule:
   - true if the item/area is clearly and unambiguously visible in the frame,
   - false only if that area is clearly visible AND the item is clearly not present,
   - null when the area is cropped out, obscured, or too ambiguous to judge.

Fields (keys) to return:
- person_visible: boolean
- body_crop_type: "full_body" | "upper_body" | "mid_body" | "close_crop" | "unclear"
- top_type: short text like "tank top", "t-shirt", "button-up", or null (1–3 words, no commas)
- top_fit: "fitted" | "relaxed" | "oversized" | "unclear"
- top_tucked: true | false | null (null when unclear or mixed)
- outerwear_visible: boolean | null
- bottom_type: short text like "jeans", "trousers", "shorts", or null (1–3 words, no commas)
- bottom_fit: "fitted" | "relaxed" | "oversized" | "unclear"
- waist_visible: boolean | null
- waist_definition_visible: boolean | null (true if the waistline is clearly defined by fit, cut, or styling)
- shoe_visible: boolean | null
- pant_hem_visible: boolean | null (true only if the lower pant edge / hem area is clearly visible)
- sleeve_visible: boolean | null
- cuff_visible: boolean | null
- ear_visibility: "visible" | "hidden" | "unclear"
- hair_visibility: very short text or null (1–3 words, no commas)
- necklace_visible: boolean | null
- bracelets_visible: boolean | null
- watch_visible: boolean | null
- ring_visible: boolean | null
- belt_visible: boolean | null
- accessory_summary: very short text summary of visible accessories, or null (1–3 words, no commas)
- color_palette_summary: very short text summary of the main colors, or null (1–3 words, no commas)
- silhouette_read: very short text like "streamlined", "boxy", "relaxed", or null (1–3 words, no commas)
- background_simple_or_busy: "simple" | "busy" | "unclear"
- lighting_quality: very short text like "even", "harsh", "dim", or null (1–3 words, no commas)
- outfit_visibility_quality: very short text describing how clearly the outfit can be seen, or null (1–3 words, no commas)

Output:
- Only the JSON object, nothing else.`;

const VISIBLE_FACTS_USER_PROMPT =
  "Look at the image and reply with a single JSON object containing the requested visible facts. Do not add any extra keys or commentary.";

function coerceBooleanOrNull(value: unknown): boolean | null {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const v = value.toLowerCase().trim();
    if (v === "true") return true;
    if (v === "false") return false;
  }
  return null;
}

function coerceFit(value: unknown): FitDescriptor {
  if (typeof value !== "string") return "unclear";
  const v = value.toLowerCase().trim();
  if (v === "fitted") return "fitted";
  if (v === "relaxed") return "relaxed";
  if (v === "oversized") return "oversized";
  return "unclear";
}

function coerceBodyCropType(value: unknown): BodyCropType {
  if (typeof value !== "string") return "unclear";
  const v = value.toLowerCase().trim();
  if (v === "full_body") return "full_body";
  if (v === "upper_body") return "upper_body";
  if (v === "mid_body") return "mid_body";
  if (v === "close_crop") return "close_crop";
  return "unclear";
}

function coerceTriState(value: unknown): VisibilityTriState {
  if (typeof value !== "string") return "unclear";
  const v = value.toLowerCase().trim();
  if (v === "visible") return "visible";
  if (v === "hidden") return "hidden";
  return "unclear";
}

function coerceSimpleBackground(value: unknown): "simple" | "busy" | "unclear" {
  if (typeof value !== "string") return "unclear";
  const v = value.toLowerCase().trim();
  if (v === "simple") return "simple";
  if (v === "busy") return "busy";
  return "unclear";
}

function parseVisibleFacts(raw: unknown): VisibleFacts {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { ...DEFAULT_VISIBLE_FACTS };
  }
  const p = raw as Record<string, unknown>;
  return {
    person_visible: typeof p.person_visible === "boolean" ? p.person_visible : true,
    body_crop_type: coerceBodyCropType(p.body_crop_type),
    top_type: typeof p.top_type === "string" ? p.top_type : null,
    top_fit: coerceFit(p.top_fit),
    top_tucked: coerceBooleanOrNull(p.top_tucked),
    outerwear_visible: coerceBooleanOrNull(p.outerwear_visible),
    bottom_type: typeof p.bottom_type === "string" ? p.bottom_type : null,
    bottom_fit: coerceFit(p.bottom_fit),
    waist_visible: coerceBooleanOrNull(p.waist_visible),
    waist_definition_visible: coerceBooleanOrNull(p.waist_definition_visible),
    shoe_visible: coerceBooleanOrNull(p.shoe_visible),
    pant_hem_visible: coerceBooleanOrNull(p.pant_hem_visible),
    sleeve_visible: coerceBooleanOrNull(p.sleeve_visible),
    cuff_visible: coerceBooleanOrNull(p.cuff_visible),
    ear_visibility: coerceTriState(p.ear_visibility),
    hair_visibility: typeof p.hair_visibility === "string" ? p.hair_visibility : null,
    necklace_visible: coerceBooleanOrNull(p.necklace_visible),
    bracelets_visible: coerceBooleanOrNull(p.bracelets_visible),
    watch_visible: coerceBooleanOrNull(p.watch_visible),
    ring_visible: coerceBooleanOrNull(p.ring_visible),
    belt_visible: coerceBooleanOrNull(p.belt_visible),
    accessory_summary: typeof p.accessory_summary === "string" ? p.accessory_summary : null,
    color_palette_summary:
      typeof p.color_palette_summary === "string" ? p.color_palette_summary : null,
    silhouette_read: typeof p.silhouette_read === "string" ? p.silhouette_read : null,
    background_simple_or_busy: coerceSimpleBackground(p.background_simple_or_busy),
    lighting_quality: typeof p.lighting_quality === "string" ? p.lighting_quality : null,
    outfit_visibility_quality:
      typeof p.outfit_visibility_quality === "string" ? p.outfit_visibility_quality : null,
  };
}

function stripMarkdownFences(text: string): string {
  const trimmed = text.trim();
  const fenceMatch = trimmed.match(/```[a-zA-Z0-9_-]*\s*([\s\S]*?)```/);
  if (fenceMatch && fenceMatch[1]) {
    return fenceMatch[1].trim();
  }
  if (trimmed.startsWith("```") && trimmed.endsWith("```")) {
    return trimmed.slice(3, -3).trim();
  }
  return trimmed;
}

function extractJSONObjectSegment(text: string): string | null {
  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
    return null;
  }
  return text.slice(firstBrace, lastBrace + 1);
}

function tryParseVisibleFactsFromString(
  raw: string,
  runId?: string
): { parsed: Record<string, unknown> | null; usedRepair: boolean; errorMessage?: string } {
  let cleaned = stripMarkdownFences(raw);

  // First attempt: direct parse.
  try {
    const direct = JSON.parse(cleaned) as Record<string, unknown>;
    return { parsed: direct, usedRepair: false };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.log(`${LOG_PREFIX} visible-facts direct JSON parse failed`, { runId, message });
  }

  // Second attempt: extract first JSON object-looking segment.
  const segment = extractJSONObjectSegment(cleaned);
  if (!segment) {
    return {
      parsed: null,
      usedRepair: true,
      errorMessage: "No JSON object delimiters found",
    };
  }

  try {
    const repaired = JSON.parse(segment) as Record<string, unknown>;
    return { parsed: repaired, usedRepair: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { parsed: null, usedRepair: true, errorMessage: message };
  }
}

function classifyEvaluability(facts: VisibleFacts): EvaluabilityState {
  if (!facts.person_visible) return "unevaluable";

  const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
  const crop = facts.body_crop_type;

  if (
    visibility.includes("hard to see") ||
    visibility.includes("very limited") ||
    visibility.includes("cannot see") ||
    visibility.includes("barely") ||
    visibility.includes("poor") ||
    visibility.includes("unclear")
  ) {
    return "unevaluable";
  }

  if (
    visibility.includes("partially") ||
    visibility.includes("some parts") ||
    crop === "close_crop" ||
    crop === "mid_body"
  ) {
    return "limited_but_usable";
  }

  return "clearly_evaluable";
}

/** Weights: fit+proportion 60%, color 25%, occasion 10%, photo clarity 5%. Outfit quality drives the score; photo has minimal impact. */
const SUBSCORE_WEIGHTS = {
  composition: 0.60,  // fit/tailoring (40%) + proportion/silhouette (20%) — combined as primary
  presentation: 0.25, // color coordination and palette balance
  purposeFit: 0.10,   // style cohesion and occasion appropriateness
  lighting: 0.05,     // photo clarity only; do not penalize if outfit is visible
} as const;

/** Compute overall score from weighted subscores. Outfit (composition, presentation, purposeFit) dominates; lighting is minimal. */
function overallFromSubscores(subscores: AnalysisSubscores): number {
  const weighted =
    subscores.composition * SUBSCORE_WEIGHTS.composition +
    subscores.presentation * SUBSCORE_WEIGHTS.presentation +
    subscores.purposeFit * SUBSCORE_WEIGHTS.purposeFit +
    subscores.lighting * SUBSCORE_WEIGHTS.lighting;
  return roundToOneDecimal(weighted);
}

const SUBSCORE_LABELS: Record<keyof AnalysisSubscores, string> = {
  composition: "fit & proportion",
  lighting: "photo clarity",
  presentation: "color coordination",
  purposeFit: "occasion fit",
};

/** One-sentence explanation from subscores: highlight strongest and weakest dimensions. */
function deriveScoreExplanation(subscores: AnalysisSubscores): string {
  const entries = (["composition", "lighting", "presentation", "purposeFit"] as const).map(
    (k) => [k, subscores[k]] as const
  );
  const sorted = [...entries].sort((a, b) => b[1] - a[1]);
  const [highKey, highVal] = sorted[0];
  const [lowKey, lowVal] = sorted[3];
  const highLabel = SUBSCORE_LABELS[highKey];
  const lowLabel = SUBSCORE_LABELS[lowKey];
  if (highKey === lowKey || Math.abs(highVal - lowVal) < 0.3) {
    return `Scores are balanced across ${highLabel} and other factors.`;
  }
  const secondLabel = SUBSCORE_LABELS[sorted[1][0]];
  return `${highLabel} and ${secondLabel} are strongest here, while ${lowLabel} slightly reduces the overall score.`;
}

// --- Rule-based subscores from visible facts (Stage 2 inputs) ---

function clampSubscoreToUserRange(value: number): number {
  // Allow a wider spread similar to the earlier app feel:
  // very weak looks can dip toward mid-3s, strong looks can approach mid/high-9s,
  // but we still avoid extreme 0/10 style scores.
  const clamped = Math.min(9.4, Math.max(3.5, value));
  return roundToOneDecimal(clamped);
}

function deriveCompositionScore(facts: VisibleFacts): number {
  // Composition: fit, proportion, silhouette. Start a touch below neutral.
  let score = 6.5;

  const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
  // Treat unclear visibility as a modest penalty; lighting handles most photo issues.
  if (visibility.includes("hard") || visibility.includes("poor") || visibility.includes("unclear")) {
    score -= 0.4;
  }

  // Very tight crops make it harder to judge full outfit balance.
  if (facts.body_crop_type === "close_crop") {
    score -= 0.6;
  } else if (facts.body_crop_type === "mid_body") {
    score -= 0.3;
  }

  // Clear waist definition usually strengthens silhouette.
  if (facts.waist_definition_visible === true) {
    score += 0.7;
  } else if (facts.waist_definition_visible === false) {
    score -= 0.3;
  }

  const silhouette = (facts.silhouette_read ?? "").toLowerCase();
  if (
    silhouette.includes("streamlined") ||
    silhouette.includes("balanced") ||
    silhouette.includes("clean") ||
    silhouette.includes("sharp")
  ) {
    score += 0.9;
  } else if (
    silhouette.includes("boxy") ||
    silhouette.includes("wide") ||
    silhouette.includes("bulky") ||
    silhouette.includes("shapeless") ||
    silhouette.includes("sloppy")
  ) {
    score -= 1.0;
  }

  // Fit descriptors: fitted vs relaxed/oversized.
  if (facts.top_fit === "fitted") {
    score += 0.4;
  } else if (facts.top_fit === "oversized" && !silhouette.includes("intentional")) {
    score -= 0.5;
  }
  if (facts.bottom_fit === "fitted") {
    score += 0.3;
  } else if (facts.bottom_fit === "oversized" && !silhouette.includes("intentional")) {
    score -= 0.3;
  }

  // Hoodie / sweatpant combos should realistically score lower on composition.
  const topType = (facts.top_type ?? "").toLowerCase();
  const bottomType = (facts.bottom_type ?? "").toLowerCase();
  const isHoodie =
    topType.includes("hoodie") || topType.includes("hooded") || topType.includes("sweatshirt");
  const isSweatpants =
    bottomType.includes("sweatpant") || bottomType.includes("jogger") || bottomType.includes("track");
  if (isHoodie) {
    score -= 0.4;
  }
  if (isSweatpants) {
    score -= 0.5;
  }
  if (isHoodie && isSweatpants) {
    // Very casual / loungewear full outfit — treat as a clearer composition downgrade.
    score -= 0.4;
  }

  // When both top and bottom read relaxed/oversized and silhouette is boxy, treat as a clearer weakness.
  if (
    (facts.top_fit === "oversized" || facts.top_fit === "relaxed") &&
    (facts.bottom_fit === "oversized" || facts.bottom_fit === "relaxed") &&
    (silhouette.includes("boxy") || silhouette.includes("wide") || silhouette.includes("shapeless"))
  ) {
    score -= 0.5;
  }

  return clampSubscoreToUserRange(score);
}

function deriveLightingScore(facts: VisibleFacts): number {
  // Lighting: photo clarity only. Keep this relatively high and low-impact.
  let score = 7.4;

  const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
  if (visibility.includes("hard") || visibility.includes("poor") || visibility.includes("unclear")) {
    score -= 0.8;
  }

  const lighting = (facts.lighting_quality ?? "").toLowerCase();
  if (lighting.includes("dim") || lighting.includes("harsh") || lighting.includes("backlit")) {
    score -= 0.6;
  } else if (lighting.includes("even") || lighting.includes("soft") || lighting.includes("natural")) {
    score += 0.3;
  }

  return clampSubscoreToUserRange(score);
}

function derivePresentationScore(facts: VisibleFacts): number {
  // Presentation: palette cohesion, accessories, background impact.
  let score = 6.5;

  const palette = (facts.color_palette_summary ?? "").toLowerCase();
  if (
    palette.includes("cohesive") ||
    palette.includes("harmonious") ||
    palette.includes("monochrome") ||
    palette.includes("tonal")
  ) {
    score += 0.9;
  } else if (
    palette.includes("clash") ||
    palette.includes("busy") ||
    palette.includes("chaotic") ||
    palette.includes("muddy")
  ) {
    score -= 1.0;
  }

  const accessoriesText = (facts.accessory_summary ?? "").toLowerCase();
  const hasAccessories =
    facts.bracelets_visible === true ||
    facts.watch_visible === true ||
    facts.necklace_visible === true ||
    facts.belt_visible === true ||
    accessoriesText.length > 0;
  if (hasAccessories) {
    score += 0.4;
  }

  const background = facts.background_simple_or_busy;
  if (background === "busy") {
    // Only penalize if the outfit already reads harder to see.
    const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
    if (visibility.includes("hard") || visibility.includes("busy") || visibility.includes("unclear")) {
      score -= 0.5;
    }
  }

  return clampSubscoreToUserRange(score);
}

function derivePurposeFitScore(
  facts: VisibleFacts,
  purpose: PhotoPurpose,
  composition: number,
  presentation: number
): number {
  // Purpose fit: how well the look matches its intended use.
  // Start from an average of composition & presentation, then move more meaningfully based on context.
  let score = (composition + presentation) / 2;

  const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
  if (visibility.includes("hard") || visibility.includes("partial") || visibility.includes("unclear")) {
    score -= 0.5;
  }

  const silhouette = (facts.silhouette_read ?? "").toLowerCase();
  const palette = (facts.color_palette_summary ?? "").toLowerCase();

  if (purpose === "professional") {
    // Relaxed/boxy silhouettes read less sharp for professional looks.
    if (
      silhouette.includes("boxy") ||
      silhouette.includes("sloppy") ||
      facts.top_fit === "oversized" ||
      facts.bottom_fit === "oversized"
    ) {
      score -= 0.7;
    }
    if (palette.includes("cohesive") || palette.includes("neutral") || palette.includes("tonal")) {
      score += 0.5;
    }
  } else if (purpose === "dating" || purpose === "social") {
    // For dating/social, cohesive or intentional color and a clean silhouette can push purposeFit up.
    if (
      silhouette.includes("streamlined") ||
      silhouette.includes("balanced") ||
      silhouette.includes("clean")
    ) {
      score += 0.5;
    }
    if (palette.includes("cohesive") || palette.includes("harmonious") || palette.includes("bold")) {
      score += 0.4;
    }
  } else if (purpose === "compare") {
    if (facts.body_crop_type === "close_crop" || facts.body_crop_type === "unclear") {
      score -= 0.7;
    }
  }

  return clampSubscoreToUserRange(score);
}

function deriveSubscoresFromFacts(facts: VisibleFacts, purpose: PhotoPurpose): AnalysisSubscores {
  const composition = deriveCompositionScore(facts);
  const lighting = deriveLightingScore(facts);
  const presentation = derivePresentationScore(facts);
  const purposeFit = derivePurposeFitScore(facts, purpose, composition, presentation);
  return { composition, lighting, presentation, purposeFit };
}

const MAX_FEEDBACK_ITEM_LENGTH = 160;
const MIN_FEEDBACK_ITEM_LENGTH = 12;

/** Phrases that are too generic to be useful; normalized (lowercase, single spaces). */
const GENERIC_PHRASES = new Set([
  "good", "nice", "great", "good job", "well done", "could be better",
  "needs improvement", "try harder", "not bad", "decent", "ok", "okay",
  "good photo", "nice photo", "great photo",
  // Intentionally allow mild outfit/style praise like "looks good" so real feedback survives.
  "add accessories", "add an accessory", "try adding an accessory", "add a statement piece",
  "add bracelet", "add a bracelet", "add bracelets", "add some bracelets",
  "add jewelry", "add some jewelry", "try adding jewelry",
]);

function normalizeForDedupe(s: string): string {
  return s.toLowerCase().replace(/\s+/g, " ").trim();
}

function isGeneric(
  text: string,
  debugContext?: { section: "strengths" | "improvements" | "suggestions"; runId?: string }
): boolean {
  const n = normalizeForDedupe(text);
  let reason: string | null = null;
  if (n.length < MIN_FEEDBACK_ITEM_LENGTH) {
    reason = "too_short";
  } else if (GENERIC_PHRASES.has(n)) {
    reason = "generic_phrase_exact";
  } else if (GENERIC_PHRASES.has(n.replace(/\.$/, ""))) {
    reason = "generic_phrase_trimmed_period";
  }
  if (reason && ANALYSIS_DEBUG_ENABLED && debugContext) {
    console.log(`${LOG_PREFIX} filtered generic ${debugContext.section} item`, {
      runId: debugContext.runId,
      reason,
      text,
    });
  }
  return reason !== null;
}

/** Words that indicate a suggestion is an actionable next step rather than a restatement of the critique. */
const ACTIONABLE_INDICATORS = new Set([
  "plain", "wall", "window", "fill", "crop", "framing", "posture", "location",
  "angle", "setting", "simpler", "different", "widen", "shoot", "try", "add",
  "experiment", "move", "shift", "softer", "brighter", "earlier", "later",
]);

function contentWords(s: string): string[] {
  return normalizeForDedupe(s)
    .replace(/[^\w\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2);
}

/** True if the suggestion is just restating an improvement (same concept, no concrete actionable step). */
function isSuggestionRedundant(suggestion: string, improvements: string[]): boolean {
  const sNorm = normalizeForDedupe(suggestion);
  const sWords = contentWords(suggestion);
  const hasActionable = sWords.some((w) => ACTIONABLE_INDICATORS.has(w));
  if (hasActionable && sWords.length >= 6) return false;

  for (const imp of improvements) {
    const iNorm = normalizeForDedupe(imp);
    if (sNorm === iNorm || sNorm.includes(iNorm) || iNorm.includes(sNorm)) return true;
    const iWords = contentWords(imp);
    const overlap = sWords.filter((w) => iWords.includes(w)).length;
    if (overlap >= 2 && sWords.length <= 10 && !hasActionable) return true;
  }
  return false;
}

/** Remove exact/substring duplicates and suggestions that only restate an improvement. */
function dropCrossSectionDuplicates(
  suggestions: string[],
  improvements: string[]
): string[] {
  const improvementKeys = new Set(improvements.map(normalizeForDedupe));
  return suggestions.filter((s) => {
    const key = normalizeForDedupe(s);
    if (improvementKeys.has(key)) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} suggestion dropped as exact improvement duplicate`, {
          text: s,
        });
      }
      return false;
    }
    for (const ik of improvementKeys) {
      if (key.includes(ik) || ik.includes(key)) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} suggestion dropped as substring improvement duplicate`, {
            text: s,
            improvementKey: ik,
          });
        }
        return false;
      }
    }
    if (isSuggestionRedundant(s, improvements)) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} suggestion dropped as redundant with improvement`, { text: s });
      }
      return false;
    }
    return true;
  });
}

function sanitizeFeedbackItems(items: string[]): string[] {
  const seen = new Set<string>();
  return items
    .map((s) => String(s).trim().slice(0, MAX_FEEDBACK_ITEM_LENGTH))
    .filter((s) => {
      if (s.length === 0) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} sanitized out empty/whitespace item`);
        }
        return false;
      }
      return true;
    })
    .filter((s) => {
      const key = normalizeForDedupe(s);
      if (seen.has(key)) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} sanitized out duplicate item`, { text: s });
        }
        return false;
      }
      seen.add(key);
      return true;
    });
}

// Normalize raw score from the AI into a safe 0–10 value, with robust parsing and logging.
function normalizeScore(value: unknown): number {
  let extracted: number | null = null;

  if (typeof value === "number") {
    extracted = value;
  } else if (typeof value === "string") {
    const match = value.match(/-?\d+(\.\d+)?/);
    if (match) {
      extracted = Number(match[0]);
    }
  }

  if (extracted === null || Number.isNaN(extracted)) {
    console.log(`${LOG_PREFIX} normalizeScore: fallback used`, {
      rawScore: value,
      normalizedScore: 5.5,
    });
    return roundToOneDecimal(5.5);
  }

  // If the model explicitly returned 0, allow 0. Otherwise avoid collapsing bad values to 0.
  if (extracted < 0) {
    if (extracted === 0) {
      console.log(`${LOG_PREFIX} normalizeScore: clamped explicit 0`, {
        rawScore: value,
        normalizedScore: 0,
      });
      return 0;
    }
    console.log(`${LOG_PREFIX} normalizeScore: negative score treated as invalid, using 5.5`, {
      rawScore: value,
      parsedNumeric: extracted,
      normalizedScore: 5.5,
    });
    return roundToOneDecimal(5.5);
  }

  let clamped = extracted;
  if (extracted > 10) clamped = 10;

  const normalized = roundToOneDecimal(clamped);
  console.log(`${LOG_PREFIX} normalizeScore: normalized`, {
    rawScore: value,
    parsedNumeric: extracted,
    normalizedScore: normalized,
  });
  return normalized;
}

function parseFullResponse(parsed: unknown, debug?: AnalysisDebugInfo | null): AnalysisResponse | null {
  if (!parsed || typeof parsed !== "object") return null;
  const p = parsed as Record<string, unknown>;

  const isValid = p.isValid === true;
  const validationMessage =
    p.validationMessage != null && typeof p.validationMessage === "string"
      ? String(p.validationMessage).trim()
      : null;
  const reason = isValidationReason(p.reason) ? p.reason : null;

  if (!isValid) {
    const message =
      validationMessage && validationMessage.length > 0
        ? validationMessage
        : "This photo doesn't appear suitable for analysis.";
    const validReason = reason ?? "image_not_relevant";
    return {
      isValid: false,
      validationMessage: message,
      reason: validReason,
      score: null,
      subscores: null,
      strengths: [],
      improvements: [],
      suggestions: [],
      analysisTips: [],
      improvementSuggestions: [],
    };
  }

  const rawImprovementSuggestions = Array.isArray(p.improvementSuggestions)
    ? p.improvementSuggestions.map(String)
    : [];
  const improvementSuggestions = sanitizeFeedbackItems(rawImprovementSuggestions).slice(0, 3);

  if (debug) {
    debug.rawGroundedImprovements = Array.isArray(p.improvements)
      ? (p.improvements as unknown[]).map(String)
      : [];
    debug.rawGroundedStrengths = Array.isArray(p.strengths)
      ? (p.strengths as unknown[]).map(String)
      : [];
    debug.rawGroundedSuggestions = Array.isArray(p.suggestions)
      ? (p.suggestions as unknown[]).map(String)
      : [];
  }

  const scoreRaw = p.score;
  if (debug) {
    debug.rawModelScore = scoreRaw;
  }
  const fallbackScore = normalizeScore(scoreRaw);
  if (debug) {
    debug.normalizedScore = fallbackScore;
  }

  const subscores = parseSubscores(p, fallbackScore);

  const score =
    subscores != null
      ? overallFromSubscores(subscores)
      : fallbackScore;

  const rawStrengths = Array.isArray(p.strengths) ? p.strengths.map(String) : [];
  const rawImprovements = Array.isArray(p.improvements) ? p.improvements.map(String) : [];
  const rawSuggestions = Array.isArray(p.suggestions) ? p.suggestions.map(String) : [];
  const rawAnalysisTips = Array.isArray(p.analysisTips) ? p.analysisTips.map(String) : [];

  const strengthsSanitized = sanitizeFeedbackItems(rawStrengths);
  const improvementsSanitized = sanitizeFeedbackItems(rawImprovements);
  const suggestionsSanitized = sanitizeFeedbackItems(rawSuggestions);

  if (ANALYSIS_DEBUG_ENABLED) {
    console.log(`${LOG_PREFIX} stage2 text — raw`, {
      strengths: rawStrengths,
      improvements: rawImprovements,
      suggestions: rawSuggestions,
    });
    console.log(`${LOG_PREFIX} stage2 text — after sanitizeFeedbackItems`, {
      strengths: strengthsSanitized,
      improvements: improvementsSanitized,
      suggestions: suggestionsSanitized,
    });
  }

  let strengths = strengthsSanitized.filter(
    (s) => !isGeneric(s, { section: "strengths", runId: debug?.fingerprint })
  );
  let improvements = improvementsSanitized.filter(
    (s) => !isGeneric(s, { section: "improvements", runId: debug?.fingerprint })
  );
  let suggestions = suggestionsSanitized.filter(
    (s) => !isGeneric(s, { section: "suggestions", runId: debug?.fingerprint })
  );

  if (ANALYSIS_DEBUG_ENABLED) {
    console.log(`${LOG_PREFIX} stage2 text — after generic filter`, {
      strengths,
      improvements,
      suggestions,
    });
  }

  suggestions = dropCrossSectionDuplicates(suggestions, improvements);

  if (ANALYSIS_DEBUG_ENABLED) {
    console.log(`${LOG_PREFIX} stage2 text — after cross-section dedupe`, {
      strengths,
      improvements,
      suggestions,
    });
  }

  const analysisTips = sanitizeFeedbackItems(rawAnalysisTips);

  const fallbackImprovements: string[] = [];
  const fallbackSuggestions: string[] = [];
  const usingFallbackStrengths = strengths.length === 0;
  const usingFallbackImprovements = improvements.length === 0;
  const finalSuggestions = suggestions.length > 0 ? suggestions : fallbackSuggestions;
  const usingFallbackSuggestions = finalSuggestions.length === 0;

  if (debug) {
    debug.usedFallbackStrengths = usingFallbackStrengths;
    debug.usedFallbackImprovements = usingFallbackImprovements;
    debug.usedFallbackSuggestions = usingFallbackSuggestions;
  }

  const scoreExplanation = subscores ? deriveScoreExplanation(subscores) : null;

  return {
    isValid: true,
    validationMessage: null,
    reason: null,
    score,
    subscores,
    strengths,
    improvements: improvements.length > 0 ? improvements : fallbackImprovements,
    suggestions: finalSuggestions,
    analysisTips,
    improvementSuggestions: improvementSuggestions.length > 0 ? improvementSuggestions : undefined,
    scoreExplanation: scoreExplanation ?? undefined,
  };
}

/** Parse phase-1 validation-only response into an invalid AnalysisResponse when isValid is false. */
function parseValidationResponse(raw: string): { valid: true } | { valid: false; response: AnalysisResponse } {
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { valid: true };
  }
  if (parsed.isValid === true) return { valid: true };
  const validationMessage =
    parsed.validationMessage != null && typeof parsed.validationMessage === "string"
      ? String(parsed.validationMessage).trim()
      : "This photo doesn't appear suitable for analysis.";
  const reason = isValidationReason(parsed.reason) ? parsed.reason : "image_not_relevant";
  return {
    valid: false,
    response: {
      isValid: false,
      validationMessage: validationMessage || "This photo doesn't appear suitable for analysis.",
      reason,
      score: null,
      subscores: null,
      strengths: [],
      improvements: [],
      suggestions: [],
      analysisTips: [],
      improvementSuggestions: [],
    },
  };
}

// --- Stage 3: contradiction / sanity cleanup ---

function sanitizeContradictorySuggestions(
  facts: VisibleFacts,
  analysis: AnalysisResponse
): AnalysisResponse {
  const shouldDropTuckAdvice =
    facts.top_tucked === true;
  const braceletsPresent =
    facts.bracelets_visible === true || facts.watch_visible === true;
  const shoesHidden = facts.shoe_visible === false;
  const pantHemHidden = facts.pant_hem_visible === false;
  const earsHidden = facts.ear_visibility === "hidden" || facts.ear_visibility === "unclear";
  const topClearlyFitted = facts.top_fit === "fitted";
  const beltPresent = facts.belt_visible === true;
  const beltVisibilityUnclear = facts.belt_visible == null;
  const braceletOrWatchUnclear = facts.bracelets_visible == null && facts.watch_visible == null;
  const necklacePresent = facts.necklace_visible === true;
  const necklaceUnclear = facts.necklace_visible == null;
  const ringsPresent = facts.ring_visible === true;
  const ringsUnclear = facts.ring_visible == null;
  const accessorySummary = (facts.accessory_summary ?? "").toLowerCase().trim();
  const anyAccessoriesPresent =
    beltPresent ||
    braceletsPresent ||
    necklacePresent ||
    ringsPresent ||
    accessorySummary.length > 0;

  const originalImprovements = analysis.improvements;
  const originalSuggestions = analysis.suggestions;

  function keepItem(text: string): boolean {
    const t = normalizeForDedupe(text);

    if (shouldDropTuckAdvice && /\btuck(ed|ing)?\b/.test(t)) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} dropping tuck-related advice due to top_tucked=true`, {
          text,
        });
      }
      return false;
    }

    // Accessory conservatism: avoid speculative advice when visibility is unclear.
    if (beltVisibilityUnclear && t.includes("belt")) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} dropping belt-related advice due to unclear belt visibility`, { text });
      }
      return false;
    }
    if (braceletOrWatchUnclear && (t.includes("bracelet") || t.includes("bracelets") || t.includes("watch") || t.includes("wrist"))) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} dropping bracelet/watch advice due to unclear wrist visibility`, { text });
      }
      return false;
    }
    if (necklaceUnclear && t.includes("necklace")) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} dropping necklace advice due to unclear neck visibility`, { text });
      }
      return false;
    }
    if (ringsUnclear && (t.includes("ring") || t.includes("rings"))) {
      if (ANALYSIS_DEBUG_ENABLED) {
        console.log(`${LOG_PREFIX} dropping ring advice due to unclear hand visibility`, { text });
      }
      return false;
    }

    // Hard "already present" constraints for accessories.
    if (beltPresent) {
      const beltPhrases = [
        "add a belt",
        "add belt",
        "try a belt",
        "try adding a belt",
        "consider a belt",
        "belt could help",
        "belt would help",
        "introduce a belt",
        "include a belt",
        "wear a belt",
      ];
      if (beltPhrases.some((p) => t.includes(p))) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} dropping belt-add advice due to belt_visible=true`, { text });
        }
        return false;
      }
    }

    if (braceletsPresent) {
      const braceletPhrases = [
        "add a bracelet",
        "add bracelet",
        "add bracelets",
        "try a bracelet",
        "add a watch",
        "add watch",
        "add a wrist accessory",
        "add wrist accessories",
      ];
      if (braceletPhrases.some((p) => t.includes(p))) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} dropping bracelet/watch-add advice due to bracelets/watch already visible`, {
            text,
          });
        }
        return false;
      }
    }

    if (necklacePresent) {
      const necklacePhrases = [
        "add a necklace",
        "add necklace",
        "try a necklace",
        "layer a necklace",
      ];
      if (necklacePhrases.some((p) => t.includes(p))) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} dropping necklace-add advice due to necklace_visible=true`, { text });
        }
        return false;
      }
    }

    if (ringsPresent) {
      const ringPhrases = [
        "add rings",
        "add a ring",
        "add some rings",
      ];
      if (ringPhrases.some((p) => t.includes(p))) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} dropping ring-add advice due to ring_visible=true`, { text });
        }
        return false;
      }
    }

    if (anyAccessoriesPresent) {
      const genericAccessoryPhrases = [
        "add accessories",
        "add some accessories",
        "add an accessory",
        "more accessories",
        "extra accessories",
      ];
      if (genericAccessoryPhrases.some((p) => t.includes(p))) {
        if (ANALYSIS_DEBUG_ENABLED) {
          console.log(`${LOG_PREFIX} dropping generic accessory-add advice due to accessories already present`, {
            text,
          });
        }
        return false;
      }
    }

    if (shoesHidden && (t.includes("shoe") || t.includes("sneaker") || t.includes("boot") || t.includes("footwear"))) {
      return false;
    }

    if (pantHemHidden && (t.includes("hem") || t.includes("pant length") || t.includes("shorten the pants") || t.includes("crop the pants"))) {
      return false;
    }

    if (earsHidden && (t.includes("earring") || t.includes("earrings"))) {
      return false;
    }

    if (topClearlyFitted && (t.includes("more fitted") || t.includes("tighter") || t.includes("tighten the waist") || t.includes("closer to the body") || t.includes("more form fitting"))) {
      return false;
    }

    return true;
  }

  const cleanedImprovements = analysis.improvements.filter(keepItem);
  const cleanedSuggestions = analysis.suggestions.filter(keepItem);
  const cleanedImprovementSuggestions =
    analysis.improvementSuggestions?.filter(keepItem) ?? analysis.improvementSuggestions;

    if (ANALYSIS_DEBUG_ENABLED) {
      console.log(`${LOG_PREFIX} contradictions cleanup — already_present`, {
        top_tucked: facts.top_tucked,
        belt_visible: facts.belt_visible,
        bracelets_visible: facts.bracelets_visible,
        watch_visible: facts.watch_visible,
        necklace_visible: facts.necklace_visible,
        ring_visible: facts.ring_visible,
        shoe_visible: facts.shoe_visible,
        ear_visibility: facts.ear_visibility,
        originalSuggestions,
        cleanedSuggestions,
        originalImprovements,
        cleanedImprovements,
      });
    }

  return {
    ...analysis,
    improvements: cleanedImprovements,
    suggestions: cleanedSuggestions,
    improvementSuggestions:
      cleanedImprovementSuggestions && cleanedImprovementSuggestions.length > 0
        ? cleanedImprovementSuggestions
        : analysis.improvementSuggestions,
  };
}

export async function analyzePhotoWithAI(
  imageBase64: string,
  purpose: PhotoPurpose,
  runId?: string
): Promise<AnalysisResponse> {
  const apiKey = process.env.OPENAI_API_KEY?.trim();

  if (!apiKey) {
    console.log(`${LOG_PREFIX} Falling back to mock analysis: missing API key`);
    if (ANALYSIS_DEBUG_ENABLED) {
      console.log(`${LOG_PREFIX} debug: getFallbackMockResult() used due to missing API key`);
    }
    return getFallbackMockResult();
  }

  try {
    const openai = new OpenAI({ apiKey });
    const model = getModel();

    const compressedBase64 = await resizeAndCompressImage(imageBase64);
    const imageUrl = compressedBase64.startsWith("data:")
      ? compressedBase64
      : `data:image/jpeg;base64,${compressedBase64}`;

    const fingerprint = computeImageFingerprint(compressedBase64);

    const debugInfo: AnalysisDebugInfo | null = ANALYSIS_DEBUG_ENABLED
      ? {
          purpose,
          fingerprint,
          cacheHitType: "none",
        }
      : null;

    // Fast path: exact same normalized image seen before.
    const exactCached = ANALYSIS_CACHE.get(fingerprint);
    if (exactCached && exactCached.purpose === purpose) {
      exactCached.lastUsedAt = Date.now();
      console.log(`${LOG_PREFIX} cache hit: exact image fingerprint`, { purpose });
      if (debugInfo) {
        debugInfo.cacheHitType = "exact";
        debugInfo.finalStrengths = exactCached.response.strengths;
        debugInfo.finalImprovements = exactCached.response.improvements;
        debugInfo.finalSuggestions = exactCached.response.suggestions;
        debugInfo.finalAnalysisTips = exactCached.response.analysisTips;
        debugInfo.finalScore = exactCached.response.score;
        logDebugSnapshot("exact_cache_return", debugInfo);
      }
      return exactCached.response;
    }

    // Skip phase-1 validation for improve_fit: the photo was already validated when we produced the result screen.
    // Re-running validation can intermittently reject the same image and show "This photo doesn't appear suitable for analysis."
    const skipPhase1Validation = purpose === "improve_fit";

    if (!skipPhase1Validation) {
      console.log(`${LOG_PREFIX} OpenAI validation request started`);
      const validationCompletion = await openai.chat.completions.create({
        model,
        messages: [
          { role: "system", content: VALIDATION_SYSTEM },
          {
            role: "user",
            content: [
              { type: "image_url", image_url: { url: imageUrl, detail: "low" } },
              { type: "text", text: VALIDATION_USER },
            ],
          },
        ],
        response_format: { type: "json_object" },
        max_tokens: 80,
      });

      console.log(`${LOG_PREFIX} OpenAI validation response received`);

      const validationRaw = validationCompletion.choices[0]?.message?.content;
      if (typeof validationRaw === "string") {
        const validation = parseValidationResponse(validationRaw);
        if (!validation.valid) {
          console.log(`${LOG_PREFIX} guardrail check: failed`, {
            reason: validation.response.reason,
            purpose,
          });
          if (debugInfo) {
            debugInfo.phase1Rejected = true;
            debugInfo.phase1Reason = validation.response.reason ?? null;
            debugInfo.finalStrengths = validation.response.strengths;
            debugInfo.finalImprovements = validation.response.improvements;
            debugInfo.finalSuggestions = validation.response.suggestions;
            debugInfo.finalAnalysisTips = validation.response.analysisTips;
            debugInfo.finalScore = validation.response.score;
            logDebugSnapshot("phase1_validation_rejected", debugInfo);
          }
          return validation.response;
        }
      }
      console.log(`${LOG_PREFIX} guardrail check: passed`);
    } else {
      console.log(`${LOG_PREFIX} improve_fit: skipping phase-1 validation (photo already validated)`);
    }

    const fullAnalysisDetail = "low";
    const fullAnalysisMaxTokens = 400;

    // Stage 1: extract conservative visible facts from the image
    console.log(`${LOG_PREFIX} OpenAI visible-facts request started`, {
      model,
      purpose,
      detail: fullAnalysisDetail,
    });
    const factsCompletion = await openai.chat.completions.create({
      model,
      messages: [
        { role: "system", content: VISIBLE_FACTS_SYSTEM_PROMPT },
        {
          role: "user",
          content: [
            { type: "image_url", image_url: { url: imageUrl, detail: fullAnalysisDetail } },
            { type: "text", text: VISIBLE_FACTS_USER_PROMPT },
          ],
        },
      ],
      response_format: { type: "json_object" },
      max_tokens: 400,
    });

    const rawFacts = factsCompletion.choices[0]?.message?.content;
    if (ANALYSIS_DEBUG_ENABLED) {
      const choiceMeta = factsCompletion.choices[0];
      console.log(`${LOG_PREFIX} visible-facts metadata`, {
        runId,
        finish_reason: choiceMeta?.finish_reason,
        usage: factsCompletion.usage,
      });
    }
    let visibleFacts: VisibleFacts = { ...DEFAULT_VISIBLE_FACTS };
    let visibleFactsFromFallback = false;
    if (typeof rawFacts === "string") {
      const preview = rawFacts.length > 600 ? `${rawFacts.slice(0, 600)}…` : rawFacts;
      console.log(`${LOG_PREFIX} visible-facts raw content`, {
        runId,
        length: rawFacts.length,
        preview,
      });
      const { parsed, usedRepair, errorMessage } = tryParseVisibleFactsFromString(rawFacts, runId);
      if (parsed) {
        visibleFacts = parseVisibleFacts(parsed);
        console.log(`${LOG_PREFIX} visible-facts parsed successfully`, {
          runId,
          usedRepair,
        });
      } else {
        visibleFactsFromFallback = true;
        console.log(`${LOG_PREFIX} visible-facts parsing failed after repair, using degraded fallback`, {
          runId,
          errorMessage,
        });
        visibleFacts = { ...DEFAULT_VISIBLE_FACTS, outfit_visibility_quality: "parse_failed" };
      }
    } else {
      visibleFactsFromFallback = true;
      console.log(`${LOG_PREFIX} visible-facts response missing or non-string, using degraded fallback`, {
        runId,
        contentType: typeof rawFacts,
      });
      visibleFacts = { ...DEFAULT_VISIBLE_FACTS, outfit_visibility_quality: "parse_failed" };
    }

    // Derive structured subscores and overall score from visible facts (fact-driven scoring).
    const derivedSubscores = visibleFactsFromFallback
      ? subscoresFromScore(6.5)
      : deriveSubscoresFromFacts(visibleFacts, purpose);
    const derivedScore = overallFromSubscores(derivedSubscores);
    const analysisContext = {
      purpose,
      visibleFacts,
      subscores: derivedSubscores,
      score: derivedScore,
    };
    const qualityBucket =
      derivedScore < 6.3 ? "weak" : derivedScore < 7.0 ? "neutral" : derivedScore < 7.7 ? "strong" : "excellent";
    console.log(`${LOG_PREFIX} derived scores from visible facts`, {
      purpose,
      subscores: derivedSubscores,
      score: derivedScore,
      qualityBucket,
    });
    if (ANALYSIS_DEBUG_ENABLED) {
      console.log(`${LOG_PREFIX} key accessory facts`, {
        belt_visible: visibleFacts.belt_visible,
        bracelets_visible: visibleFacts.bracelets_visible,
        watch_visible: visibleFacts.watch_visible,
        necklace_visible: visibleFacts.necklace_visible,
        ring_visible: visibleFacts.ring_visible,
        top_tucked: visibleFacts.top_tucked,
        shoe_visible: visibleFacts.shoe_visible,
        ear_visibility: visibleFacts.ear_visibility,
      });
    }

    if (debugInfo) {
      debugInfo.visibleFactsSummary = {
        body_crop_type: visibleFacts.body_crop_type,
        outfit_visibility_quality: visibleFacts.outfit_visibility_quality,
        background_simple_or_busy: visibleFacts.background_simple_or_busy,
        color_palette_summary: visibleFacts.color_palette_summary,
        silhouette_read: visibleFacts.silhouette_read,
        shoe_visible: visibleFacts.shoe_visible,
        pant_hem_visible: visibleFacts.pant_hem_visible,
        belt_visible: visibleFacts.belt_visible,
        bracelets_visible: visibleFacts.bracelets_visible,
        watch_visible: visibleFacts.watch_visible,
        necklace_visible: visibleFacts.necklace_visible,
        ring_visible: visibleFacts.ring_visible,
        top_tucked: visibleFacts.top_tucked,
        ear_visibility: visibleFacts.ear_visibility,
      };
      debugInfo.evaluability = classifyEvaluability(visibleFacts);
      debugInfo.derivedSubscores = derivedSubscores;
      debugInfo.derivedScore = derivedScore;
      debugInfo.visibleFactsFromFallback = visibleFactsFromFallback;
    }

    // Check for near-duplicate analyses based on visible facts (text reuse disabled).
    const allowNearDuplicateAnchor =
      !visibleFactsFromFallback &&
      (visibleFacts.outfit_visibility_quality ?? "").toLowerCase() !== "parse_failed";
    console.log(`${LOG_PREFIX} near-duplicate cache check`, {
      purpose,
      runId,
      allowNearDuplicateAnchor,
      outfit_visibility_quality: visibleFacts.outfit_visibility_quality,
      fromFallback: visibleFactsFromFallback,
    });

    let bestMatch: { entry: CachedAnalysisEntry; similarity: number } | null = null;
    if (allowNearDuplicateAnchor) {
      bestMatch = findBestCachedMatch(purpose, visibleFacts);
      if (bestMatch) {
        console.log(`${LOG_PREFIX} cache anchor candidate: near-duplicate facts match (text NOT reused)`, {
          purpose,
          similarity: bestMatch.similarity,
          runId,
        });
        if (debugInfo) {
          debugInfo.cacheHitType = "near_duplicate";
          debugInfo.cacheAnchorSimilarity = bestMatch.similarity;
        }
      }
    } else {
      console.log(`${LOG_PREFIX} skipping near-duplicate cache anchoring due to fallback/low-confidence facts`, {
        purpose,
        runId,
      });
    }

    // Stage 2: grounded style analysis based ONLY on extracted facts and derived scores
    console.log(`${LOG_PREFIX} OpenAI grounded analysis request started`, {
      model,
      purpose,
      max_tokens: fullAnalysisMaxTokens,
    });
    const systemPrompt = getFullAnalysisSystemPrompt(purpose);
    const userText =
      purpose === "improve_fit"
        ? "You are given structured visible facts about the outfit (no direct access to the image). Using ONLY these facts, output up to 3 specific, actionable outfit improvement suggestions. Do not contradict the facts, do not infer hidden details, and do not recommend actions that are already present in the facts. Focus on fit, color balance, layering, and visible accessories. Do not mention lighting, framing, or camera. Output only valid JSON."
        : "You are given structured visible facts about the outfit and PRECOMPUTED numeric subscores and overall score (no direct access to the image). Using ONLY this structured context, explain the score, list strengths, and list grounded improvements and suggestions. Do not contradict the facts, do not infer hidden details, and do not recommend actions that are already present in the facts. Do NOT change or rescore the numeric values. No generic praise, no repeated points across sections. Output only valid JSON.";

    const groundedCompletion = await openai.chat.completions.create({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Here is the structured analysis context as JSON, including visible facts and PRECOMPUTED numeric subscores and overall score. Base your entire analysis ONLY on this context. Do not contradict the facts and do NOT change the numbers:\n" +
                JSON.stringify(analysisContext),
            },
            { type: "text", text: userText },
          ],
        },
      ],
      response_format: { type: "json_object" },
      max_tokens: fullAnalysisMaxTokens,
    });

    const raw = groundedCompletion.choices[0]?.message?.content;
    console.log(`${LOG_PREFIX} OpenAI analysis response received`, {
      contentExists: raw != null && typeof raw === "string",
      contentLength: typeof raw === "string" ? raw.length : 0,
    });

    if (!raw || typeof raw !== "string") {
      console.log(`${LOG_PREFIX} structured parsing failed: empty or non-string content`);
      throw new InvalidAIResponseError("Empty or non-string AI response");
    }

    console.log(`${LOG_PREFIX} structured parsing started`);
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(raw) as Record<string, unknown>;
    } catch (parseErr) {
      console.log(`${LOG_PREFIX} structured parsing failed: JSON parse error`);
      throw new InvalidAIResponseError("Invalid JSON in AI response");
    }

    const result = parseFullResponse(parsed, debugInfo);
    if (result === null) {
      console.log(`${LOG_PREFIX} structured parsing failed: invalid response shape`);
      throw new InvalidAIResponseError("Invalid analysis response shape");
    }

    console.log(`${LOG_PREFIX} structured parsing succeeded`);

    if (!result.isValid) {
      // For improve_fit, the photo already passed analysis; avoid showing "suitable for analysis" again.
      if (purpose === "improve_fit") {
        console.log(`${LOG_PREFIX} improve_fit full analysis returned invalid; returning outfit-oriented fallback suggestions`);
        const fallbackSuggestions = [
          "Consider how the top and bottom pieces relate in proportion for a stronger silhouette.",
          "Pay attention to how visible colors work together across the outfit.",
          "If you add any extra layer or accessory, make sure it clearly supports the existing look instead of repeating what is already there.",
        ];
        const fallback: AnalysisResponse = {
          isValid: true,
          validationMessage: null,
          reason: null,
          score: 7,
          subscores: subscoresFromScore(7),
          strengths: ["Outfit was previously evaluated successfully"],
          improvements: [],
          suggestions: fallbackSuggestions,
          analysisTips: [],
          improvementSuggestions: fallbackSuggestions,
        };
        if (debugInfo) {
          debugInfo.fallbackMockUsed = true;
          debugInfo.finalStrengths = fallback.strengths;
          debugInfo.finalImprovements = fallback.improvements;
          debugInfo.finalSuggestions = fallback.suggestions;
          debugInfo.finalAnalysisTips = fallback.analysisTips;
          debugInfo.finalScore = fallback.score;
          logDebugSnapshot("improve_fit_invalid_fallback", debugInfo);
        }
        return fallback;
      }
      console.log(`${LOG_PREFIX} guardrail check (phase 2): rejected`, { reason: result.reason, purpose });
      if (debugInfo) {
        debugInfo.phase2ValidatorRejected = true;
        debugInfo.phase2ValidatorReason = result.reason ?? null;
        debugInfo.finalStrengths = result.strengths;
        debugInfo.finalImprovements = result.improvements;
        debugInfo.finalSuggestions = result.suggestions;
        debugInfo.finalAnalysisTips = result.analysisTips;
        debugInfo.finalScore = result.score;
        logDebugSnapshot("phase2_invalid_return", debugInfo);
      }
      return result;
    }

    // Override any AI-provided numeric scores with fact-driven subscores and overall score.
    // Always use freshly generated text from this run; do NOT reuse cached text from near-duplicates.
    const factDrivenResult: AnalysisResponse = {
      ...result,
      subscores: derivedSubscores,
      score: derivedScore,
      scoreExplanation: deriveScoreExplanation(derivedSubscores),
    };

    // Stage 3: deterministic contradiction cleanup based on extracted facts
    const sanitized = sanitizeContradictorySuggestions(visibleFacts, factDrivenResult);

    // Store in cache for future exact / near-duplicate analyses.
    putCachedAnalysis(fingerprint, purpose, visibleFacts, sanitized);

    if (debugInfo) {
      debugInfo.finalStrengths = sanitized.strengths;
      debugInfo.finalImprovements = sanitized.improvements;
      debugInfo.finalSuggestions = sanitized.suggestions;
      debugInfo.finalAnalysisTips = sanitized.analysisTips;
      debugInfo.finalScore = sanitized.score;
      logDebugSnapshot("final_sanitized_output", debugInfo);
    }

    let finalResponse: AnalysisResponse = sanitized;
    if (ANALYSIS_DEBUG_ENABLED && debugInfo) {
      const debugExport: AnalysisDebug = {
        visibleFactsSummary: debugInfo.visibleFactsSummary ?? null,
        evaluability: debugInfo.evaluability ?? null,
        visibleFactsFromFallback: debugInfo.visibleFactsFromFallback ?? false,
        strengthsCount: sanitized.strengths.length,
        improvementsCount: sanitized.improvements.length,
        suggestionsCount: sanitized.suggestions.length,
      };
      finalResponse = {
        ...sanitized,
        debug: debugExport,
      };
    }

    console.log(`${LOG_PREFIX} final score summary`, {
      purpose,
      subscores: finalResponse.subscores,
      score: finalResponse.score,
      fromVisibleFactsFallback: debugInfo?.visibleFactsFromFallback ?? false,
      cacheHitType: debugInfo?.cacheHitType ?? "none",
    });
    console.log(`${LOG_PREFIX} analysis complete`, { purpose, score: finalResponse.score });
    return finalResponse;
  } catch (err) {
    if (err instanceof InvalidAIResponseError) {
      throw err;
    }
    const statusCode =
      err && typeof err === "object" && "status" in err && typeof (err as { status: number }).status === "number"
        ? (err as { status: number }).status
        : undefined;
    const message = err instanceof Error ? err.message : "OpenAI request failed";
    console.error(`${LOG_PREFIX} OpenAI request failed`, { message, statusCode });
    throw new OpenAIServiceError(message, statusCode);
  }
}
