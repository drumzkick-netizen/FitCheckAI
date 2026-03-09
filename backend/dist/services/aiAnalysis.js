"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzePhotoWithAI = analyzePhotoWithAI;
const openai_1 = __importDefault(require("openai"));
const errors_1 = require("../errors");
const types_1 = require("../types");
const imageUtils_1 = require("./imageUtils");
const LOG_PREFIX = "[analyze-photo]";
function getModel() {
    const env = process.env.OPENAI_MODEL?.trim();
    return env || "gpt-4o";
}
/** Clamp to 0–10 and round to one decimal place. All scores use this for consistency. */
function roundToOneDecimal(value) {
    const clamped = Math.min(10, Math.max(0, value));
    return Math.round(clamped * 10) / 10;
}
/** Generate realistic subscores from overall score when API omits them. */
function subscoresFromScore(score) {
    const s = roundToOneDecimal(score);
    return {
        composition: roundToOneDecimal(s - 0.2),
        lighting: roundToOneDecimal(s + 0.2),
        presentation: roundToOneDecimal(s - 0.1),
        purposeFit: roundToOneDecimal(s + 0.1),
    };
}
const FALLBACK_MOCK_SCORE = 7.5;
function getFallbackMockResult() {
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
    };
}
// --- Cheap validation (phase 1): low-detail image, minimal prompt, ~80 tokens out ---
const VALIDATION_SYSTEM = `Reply with only a JSON object: { "isValid": boolean, "validationMessage": string | null, "reason": string | null }.
Set isValid to false only if the image is clearly: no person (landscape, food, pet, object, screenshot, meme). Use reason: "no_person_detected" | "outfit_not_visible" | "image_not_relevant" | "framing_too_unclear". If a person is visible or unsure, set isValid true, validationMessage and reason null. No other text.`;
const VALIDATION_USER = "Is there a clearly visible person in this image suitable for outfit/photo feedback? Reply with the JSON only.";
// --- Full analysis (phase 2): high-detail image, lean prompt ---
const CORE_PHILOSOPHY = `
CORE: This app evaluates the OUTFIT. Outfit quality does NOT require a visible face. Score based on what you can see: clothing, styling, fit, composition, presentation, and photo clarity. Do not penalize a photo just because the face is missing or unclear if the outfit is clearly visible. Strong outfit-focused photos can score well without a visible face. Do not judge personal attractiveness; focus on the outfit and the image. Do not act like every photo must show the face.`;
function getPurposeFitGuidance(purpose) {
    if (purpose === "dating") {
        return `
PURPOSE-FIT (dating): Face visibility may matter for some dating contexts (connection, profile). Mention it only when genuinely relevant—as a soft, conditional suggestion (e.g. "For dating profiles, a version with your face visible might help connection—outfit itself works well"), not a requirement. Do not lower scores or demand a visible face; a strong outfit-focused photo can still score well for dating.`;
    }
    if (purpose === "social" || purpose === "professional") {
        return `
PURPOSE-FIT (${purpose}): Mention face visibility only when it is genuinely relevant to the purpose, not as a blanket rule. If the photo works well as an outfit-focused image, say so.`;
    }
    return "";
}
function getFullAnalysisSystemPrompt(purpose) {
    const focus = {
        outfit: "Clothing fit, color, silhouette, style.",
        dating: "Warmth, approachability, framing. How well the outfit and image work for a dating context.",
        social: "Impact, composition, shareability.",
        professional: "Polish, background, presence.",
        compare: "Presentation, clarity, impact.",
    };
    const purposeBlock = getPurposeFitGuidance(purpose);
    return `Style/photo coach. (1) Validate: isValid true unless clearly no person (landscape, food, pet, object, meme). (2) If valid, score 0.0–10.0 and give feedback.
${CORE_PHILOSOPHY}

Purpose: ${purpose}. ${focus[purpose]}
${purposeBlock}

Scoring: Score with nuance based on visible evidence in the image. Use exactly one decimal place for every score. Good examples: 8.1, 8.4, 8.8, 9.2. Do not use extra decimals (e.g. 8.37) or round to whole numbers or .5 unless that truly reflects your assessment. Each of composition, lighting, presentation, purposeFit must be a decimal from 0.0 to 10.0. 9+ rare; 7–8.5 strong; 5.5–6.5 average. Explain score drivers using what you actually see (e.g. why composition is 7.2, why lighting helps or hurts).

FEEDBACK RULES (critical):
- What Works (strengths): Identify 2–3 strongest positives that are actually visible in the image. Be concrete—e.g. color coordination, clean silhouette, balanced layers, sharper presentation, strong lighting, jacket fits at the shoulders, clean background. Avoid vague praise like "nice outfit" or "good style" unless you immediately add a concrete detail (e.g. "Good style—the layers work well together"). No filler. Sound like a sharp, tasteful evaluator who explains why the score is what it is.
- Could Improve (improvements): Identify 1–3 biggest weaknesses that materially affect the score. Explain what is reducing the result—e.g. "Lighting is flat on the left side", "Crop cuts off the outfit at the knee", "Background competes for attention". Evidence-based, not generic criticism. Do not repeat the same idea in Suggestions. 1–3 bullets.
- Suggestions: Give 2–3 practical improvements the user could realistically apply in the next photo or styling attempt. Actionable and easy to act on—e.g. "Try a fill light or shoot near a window", "Crop slightly wider to show the full hem". Do NOT repeat the critique wording from Could Improve; suggest the next step, not the same observation. 2–3 bullets.
- Do not repeat the same point across strengths, improvements, and suggestions. Each section has a distinct role. Tone: concise, sharp, natural, tasteful. Focus on outfit, style, and photo effectiveness—not personal attractiveness. If the image is strong overall, still include one useful refinement. If the image is weak, still acknowledge any genuine strength. Face visibility: mention only when genuinely relevant to the selected purpose, not as a blanket rule.

Output single JSON only. No markdown.
{ "isValid": bool, "validationMessage": null|string, "reason": null|"no_person_detected"|"outfit_not_visible"|"image_not_relevant"|"framing_too_unclear", "score": number|null, "subscores": { "composition", "lighting", "presentation", "purposeFit" }|null, "strengths": [], "improvements": [], "suggestions": [] }`;
}
function clampSubscore(value) {
    const n = typeof value === "number" ? value : Number(value);
    if (Number.isNaN(n))
        return 7;
    return roundToOneDecimal(n);
}
function parseSubscores(parsed, fallbackScore) {
    const raw = parsed.subscores;
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        return subscoresFromScore(fallbackScore);
    }
    const obj = raw;
    return {
        composition: clampSubscore(obj.composition),
        lighting: clampSubscore(obj.lighting),
        presentation: clampSubscore(obj.presentation),
        purposeFit: clampSubscore(obj.purposeFit),
    };
}
/** Compute overall score from subscores (mean), rounded to one decimal, for consistency. */
function overallFromSubscores(subscores) {
    const mean = (subscores.composition + subscores.lighting + subscores.presentation + subscores.purposeFit) / 4;
    return roundToOneDecimal(mean);
}
const MAX_FEEDBACK_ITEM_LENGTH = 160;
const MIN_FEEDBACK_ITEM_LENGTH = 12;
/** Phrases that are too generic to be useful; normalized (lowercase, single spaces). */
const GENERIC_PHRASES = new Set([
    "good", "nice", "great", "good job", "well done", "could be better",
    "needs improvement", "try harder", "not bad", "decent", "ok", "okay",
    "good photo", "nice photo", "great photo", "good outfit", "nice outfit",
    "good style", "nice style", "great style", "looks good", "looks great",
]);
function normalizeForDedupe(s) {
    return s.toLowerCase().replace(/\s+/g, " ").trim();
}
function isGeneric(text) {
    const n = normalizeForDedupe(text);
    if (n.length < MIN_FEEDBACK_ITEM_LENGTH)
        return true;
    if (GENERIC_PHRASES.has(n))
        return true;
    if (GENERIC_PHRASES.has(n.replace(/\.$/, "")))
        return true;
    return false;
}
/** Remove items that duplicate or closely repeat something in another list (e.g. suggestion repeating an improvement). */
function dropCrossSectionDuplicates(suggestions, improvements) {
    const improvementKeys = new Set(improvements.map(normalizeForDedupe));
    return suggestions.filter((s) => {
        const key = normalizeForDedupe(s);
        if (improvementKeys.has(key))
            return false;
        for (const ik of improvementKeys) {
            if (key.includes(ik) || ik.includes(key))
                return false;
        }
        return true;
    });
}
function sanitizeFeedbackItems(items) {
    const seen = new Set();
    return items
        .map((s) => String(s).trim().slice(0, MAX_FEEDBACK_ITEM_LENGTH))
        .filter((s) => s.length > 0)
        .filter((s) => {
        const key = normalizeForDedupe(s);
        if (seen.has(key))
            return false;
        seen.add(key);
        return true;
    });
}
function parseFullResponse(parsed) {
    if (!parsed || typeof parsed !== "object")
        return null;
    const p = parsed;
    const isValid = p.isValid === true;
    const validationMessage = p.validationMessage != null && typeof p.validationMessage === "string"
        ? String(p.validationMessage).trim()
        : null;
    const reason = (0, types_1.isValidationReason)(p.reason) ? p.reason : null;
    if (!isValid) {
        const message = validationMessage && validationMessage.length > 0
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
        };
    }
    const scoreRaw = p.score;
    const rawScore = scoreRaw != null && typeof scoreRaw === "number"
        ? scoreRaw
        : Number(scoreRaw);
    const fallbackScore = Number.isNaN(rawScore) ? 7 : roundToOneDecimal(rawScore);
    const subscores = parseSubscores(p, fallbackScore);
    const score = subscores != null
        ? overallFromSubscores(subscores)
        : fallbackScore;
    const rawStrengths = Array.isArray(p.strengths) ? p.strengths.map(String) : [];
    const rawImprovements = Array.isArray(p.improvements) ? p.improvements.map(String) : [];
    const rawSuggestions = Array.isArray(p.suggestions) ? p.suggestions.map(String) : [];
    let strengths = sanitizeFeedbackItems(rawStrengths).filter((s) => !isGeneric(s));
    let improvements = sanitizeFeedbackItems(rawImprovements).filter((s) => !isGeneric(s));
    let suggestions = sanitizeFeedbackItems(rawSuggestions).filter((s) => !isGeneric(s));
    suggestions = dropCrossSectionDuplicates(suggestions, improvements);
    const fallbackStrengths = ["Clear subject and framing", "Outfit is visible and evaluable"];
    const fallbackImprovements = ["Refine framing or lighting for a stronger shot"];
    const fallbackSuggestions = ["Try another angle or setting for comparison"];
    return {
        isValid: true,
        validationMessage: null,
        reason: null,
        score,
        subscores,
        strengths: strengths.length > 0 ? strengths : fallbackStrengths,
        improvements: improvements.length > 0 ? improvements : fallbackImprovements,
        suggestions: suggestions.length > 0 ? suggestions : fallbackSuggestions,
    };
}
/** Parse phase-1 validation-only response into an invalid AnalysisResponse when isValid is false. */
function parseValidationResponse(raw) {
    let parsed;
    try {
        parsed = JSON.parse(raw);
    }
    catch {
        return { valid: true };
    }
    if (parsed.isValid === true)
        return { valid: true };
    const validationMessage = parsed.validationMessage != null && typeof parsed.validationMessage === "string"
        ? String(parsed.validationMessage).trim()
        : "This photo doesn't appear suitable for analysis.";
    const reason = (0, types_1.isValidationReason)(parsed.reason) ? parsed.reason : "image_not_relevant";
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
        },
    };
}
async function analyzePhotoWithAI(imageBase64, purpose) {
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) {
        console.log(`${LOG_PREFIX} Falling back to mock analysis: missing API key`);
        return getFallbackMockResult();
    }
    try {
        const openai = new openai_1.default({ apiKey });
        const model = getModel();
        const compressedBase64 = await (0, imageUtils_1.resizeAndCompressImage)(imageBase64);
        const imageUrl = compressedBase64.startsWith("data:")
            ? compressedBase64
            : `data:image/jpeg;base64,${compressedBase64}`;
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
                console.log(`${LOG_PREFIX} guardrail check: failed`, { reason: validation.response.reason, purpose });
                return validation.response;
            }
        }
        console.log(`${LOG_PREFIX} guardrail check: passed`);
        console.log(`${LOG_PREFIX} OpenAI analysis request started`);
        const systemPrompt = getFullAnalysisSystemPrompt(purpose);
        const userText = "Score and give feedback grounded in visible details from the image. Use one decimal per score (e.g. 8.1, 8.4, 8.8). No generic praise, no repeated points across sections. Output only valid JSON.";
        const completion = await openai.chat.completions.create({
            model,
            messages: [
                { role: "system", content: systemPrompt },
                {
                    role: "user",
                    content: [
                        { type: "image_url", image_url: { url: imageUrl, detail: "high" } },
                        { type: "text", text: userText },
                    ],
                },
            ],
            response_format: { type: "json_object" },
            max_tokens: 700,
        });
        console.log(`${LOG_PREFIX} OpenAI analysis response received`);
        const raw = completion.choices[0]?.message?.content;
        if (!raw || typeof raw !== "string") {
            console.log(`${LOG_PREFIX} structured parsing failed: empty or non-string content`);
            throw new errors_1.InvalidAIResponseError("Empty or non-string AI response");
        }
        console.log(`${LOG_PREFIX} structured parsing started`);
        let parsed;
        try {
            parsed = JSON.parse(raw);
        }
        catch (parseErr) {
            console.log(`${LOG_PREFIX} structured parsing failed: JSON parse error`);
            throw new errors_1.InvalidAIResponseError("Invalid JSON in AI response");
        }
        const result = parseFullResponse(parsed);
        if (result === null) {
            console.log(`${LOG_PREFIX} structured parsing failed: invalid response shape`);
            throw new errors_1.InvalidAIResponseError("Invalid analysis response shape");
        }
        console.log(`${LOG_PREFIX} structured parsing succeeded`);
        if (!result.isValid) {
            console.log(`${LOG_PREFIX} guardrail check (phase 2): rejected`, { reason: result.reason, purpose });
            return result;
        }
        console.log(`${LOG_PREFIX} analysis complete`, { purpose, score: result.score });
        return result;
    }
    catch (err) {
        if (err instanceof errors_1.InvalidAIResponseError) {
            throw err;
        }
        const statusCode = err && typeof err === "object" && "status" in err && typeof err.status === "number"
            ? err.status
            : undefined;
        const message = err instanceof Error ? err.message : "OpenAI request failed";
        console.error(`${LOG_PREFIX} OpenAI request failed`, { message, statusCode });
        throw new errors_1.OpenAIServiceError(message, statusCode);
    }
}
