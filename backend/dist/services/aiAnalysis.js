"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzePhotoWithAI = analyzePhotoWithAI;
const openai_1 = __importDefault(require("openai"));
const crypto_1 = __importDefault(require("crypto"));
const errors_1 = require("../errors");
const imageUtils_1 = require("./imageUtils");
const LOG_PREFIX = "[analyze-photo]";
const ANALYSIS_DEBUG_ENABLED = process.env.FITCHECK_DEBUG_ANALYSIS === "1" ||
    process.env.FITCHECK_DEBUG_ANALYSIS === "true";
/** Temporary debug: force gpt-4o-mini for reliability testing. */
function getModel() {
    return "gpt-4o-mini";
}
/** Abort OpenAI request after this many ms to avoid hanging; env override allowed. */
const OPENAI_REQUEST_TIMEOUT_MS = Math.min(60000, Math.max(20000, parseInt(process.env.OPENAI_REQUEST_TIMEOUT_MS || "45000", 10) || 45000));
function withTimeout(promise, ms, phase) {
    return new Promise((resolve, reject) => {
        const t = setTimeout(() => {
            reject(new errors_1.OpenAIServiceError(`${phase} timed out after ${ms}ms`, 504));
        }, ms);
        promise.then((r) => { clearTimeout(t); resolve(r); }).catch((e) => { clearTimeout(t); reject(e); });
    });
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
        analysisTips: ["Connect a valid OpenAI API key for full analysis tips."],
        improvementSuggestions: [],
        scoreExplanation: subscores ? deriveScoreExplanation(subscores) : undefined,
    };
}
function logDebugSnapshot(stage, info) {
    if (!ANALYSIS_DEBUG_ENABLED || !info)
        return;
    try {
        console.log(`${LOG_PREFIX} debug snapshot — ${stage}`, JSON.stringify(info, null, 2));
    }
    catch (err) {
        console.log(`${LOG_PREFIX} debug snapshot logging failed`, {
            stage,
            message: err instanceof Error ? err.message : String(err),
        });
    }
}
const DEFAULT_VISIBLE_FACTS = {
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
const ANALYSIS_CACHE = new Map();
const ANALYSIS_CACHE_MAX_ENTRIES = 100;
function computeImageFingerprint(normalizedBase64) {
    // Hash the compressed base64 (without data URL prefix) for stability across uploads.
    const base64 = normalizedBase64.startsWith("data:")
        ? normalizedBase64.substring(normalizedBase64.indexOf(",") + 1)
        : normalizedBase64;
    const hash = crypto_1.default.createHash("sha256");
    hash.update(base64);
    return hash.digest("hex").slice(0, 32);
}
function factsSimilarity(a, b) {
    let matches = 0;
    let total = 0;
    function cmp(av, bv) {
        total += 1;
        if (av === bv)
            matches += 1;
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
function findBestCachedMatch(purpose, facts) {
    let best = null;
    let bestSim = 0;
    const now = Date.now();
    for (const entry of ANALYSIS_CACHE.values()) {
        if (entry.purpose !== purpose)
            continue;
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
function putCachedAnalysis(fingerprint, purpose, visibleFacts, response) {
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
        let oldestKey = null;
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
// --- Single-request combined prompt (replaces separate visible-facts + grounded-analysis calls) ---
const COMBINED_SINGLE_REQUEST_SYSTEM = `You are an outfit analysis assistant. Output ONE JSON object only. No markdown. Evaluate the outfit like a real stylist doing a fit check.

CRITICAL RULE — THIS IS A FIT CHECK, NOT A PHOTO CRITIQUE
This is a fit-check / stylist app. The subject of analysis is the person, the outfit, and how the clothing fits and works on the body. This is NOT a photography critique. The following topics are OUT OF SCOPE and must NOT appear in strengths, improvements, suggestions, or improvementSuggestions unless the outfit is genuinely impossible to evaluate: image orientation, rotating the image, cropping the image, framing, negative space, cleaner or simpler background, cluttered background, room or scenery distractions, lighting improvements, softer light sources, better camera angle, central positioning, photo composition advice, or any other camera/photography tips. If the outfit is visible enough to judge, completely ignore these topics. Only when the clothing truly cannot be judged may you mention visibility issues, and those belong ONLY in analysisTips (not in outfit feedback sections).

FIT-FIRST RULE
The most important part of the analysis is how the clothing fits and shapes the person. Pay close attention to: whether garments look fitted, relaxed, oversized, boxy, or shapeless; whether the outfit defines or hides shape; whether the silhouette looks balanced or awkward; whether top and bottom proportions work together; whether the outfit reads intentional and put-together or casual/sloppy.

SILHOUETTE RULE
Explicitly evaluate silhouette and overall visual shape. Consider: waist definition; top-to-bottom balance; whether the outfit looks streamlined or bulky; whether layers improve or hurt the shape; whether the look has structure or feels amorphous. Prioritize silhouette comments over generic comments.

PROPORTION RULE
Carefully evaluate proportion between visible garments. Examples: fitted top with balanced bottom; oversized top with overly relaxed bottom causing a shapeless look; top length affecting leg line; visual balance between upper and lower body; whether the overall look appears clean, intentional, and proportionate. If proportions are strong, call that out as a strength. If proportions are weak, mention that in improvements or suggestions.

PERSON-FIRST RULE
Judge how the outfit works ON THE PERSON, not how clothes look in isolation. Focus on: how the clothes sit on the body; whether the outfit flatters the wearer's visible shape; whether the styling enhances the person's overall presentation. Do not just identify garments; interpret how they work together on the person.

COMPOSITION VS PHOTO COMPOSITION
When you think about "composition", you are judging the outfit composition on the body: silhouette, fit, proportion, and the visual balance of clothing on the person. Do NOT treat composition as photo framing, centering, negative space, or camera positioning.

BACKGROUND & LIGHTING RULE
Ignore the background and camera composition unless they directly prevent the outfit from being evaluated. Do NOT comment on cluttered rooms, scenery, framing, centering, camera angle, negative space, or lighting setups unless the outfit cannot be seen well enough to judge. Written feedback must stay focused on outfit quality: fit, silhouette, proportion, coordination, styling, visible accessories.

SECTION GUIDANCE
What Works: Emphasize flattering fit, strong silhouette, clean proportions, cohesive styling, and visible outfit strengths on the person.
Could Improve: Emphasize weak fit, shapelessness, imbalance, awkward proportion, and visible styling mismatches.
Suggestions: Suggest ways to improve shape, balance, proportion, styling, or visible coordination. Suggestions should feel like a stylist improving the outfit, not a photographer improving the image.

TONE
Write like a modern stylist or fit-check expert: concise, visual, outfit-focused, grounded in what is visible, not generic, not overly technical.

1) visible_facts: What is clearly visible. Use exact keys. Booleans: true/false/null (null when area not visible). Enums: use listed values or "unclear". Strings: 1-3 words max.
Keys: person_visible (boolean), body_crop_type (full_body|upper_body|mid_body|close_crop|unclear), top_type, top_fit (fitted|relaxed|oversized|unclear), top_tucked (bool|null), outerwear_visible, bottom_type, bottom_fit, waist_visible, waist_definition_visible, shoe_visible, pant_hem_visible, sleeve_visible, cuff_visible, ear_visibility (visible|hidden|unclear), hair_visibility, necklace_visible, bracelets_visible, watch_visible, ring_visible, belt_visible, accessory_summary, color_palette_summary, silhouette_read, background_simple_or_busy (simple|busy|unclear), lighting_quality, outfit_visibility_quality.

2) If person_visible is false, set strengths=[], improvements=[], suggestions=[], analysisTips=[], improvementSuggestions=[] and return.

3) STRENGTHS: 2–4 short positives. Emphasize flattering fit, strong silhouette, clean proportions, cohesive styling. Outfit only; no background/scenery/lighting unless visibility is poor.

4) IMPROVEMENTS: 0–3 weaknesses. Emphasize weak fit, shapelessness, imbalance, awkward proportion, styling mismatches. Outfit only; no cleaner background/better lighting/framing unless the outfit cannot be evaluated.

5) SUGGESTIONS: 0–3 actionable tips. Focus on improving shape, balance, proportion, styling, coordination — like a stylist, not a photographer. Do NOT suggest tucking if top already tucked; do NOT suggest adding belt/bracelets/watch/necklace/rings if already visible; do NOT suggest hem/shoe/sleeve changes unless that area is clearly visible.

6) analysisTips: Only when the outfit is hard to evaluate (e.g. too dark, cropped). One short visibility tip if needed. If the outfit is clearly visible, analysisTips must be [].

7) improvementSuggestions: 0–3 outfit-only (same rules as suggestions). No photography or environment advice.`;
function getCombinedUserPrompt(purpose) {
    return `Analyze this outfit image. Purpose: ${purpose}. Reply with one JSON: { "visible_facts": {...}, "strengths": [], "improvements": [], "suggestions": [], "analysisTips": [], "improvementSuggestions": [] }.`;
}
function coerceBooleanOrNull(value) {
    if (typeof value === "boolean")
        return value;
    if (typeof value === "string") {
        const v = value.toLowerCase().trim();
        if (v === "true")
            return true;
        if (v === "false")
            return false;
    }
    return null;
}
function coerceFit(value) {
    if (typeof value !== "string")
        return "unclear";
    const v = value.toLowerCase().trim();
    if (v === "fitted")
        return "fitted";
    if (v === "relaxed")
        return "relaxed";
    if (v === "oversized")
        return "oversized";
    return "unclear";
}
function coerceBodyCropType(value) {
    if (typeof value !== "string")
        return "unclear";
    const v = value.toLowerCase().trim();
    if (v === "full_body")
        return "full_body";
    if (v === "upper_body")
        return "upper_body";
    if (v === "mid_body")
        return "mid_body";
    if (v === "close_crop")
        return "close_crop";
    return "unclear";
}
function coerceTriState(value) {
    if (typeof value !== "string")
        return "unclear";
    const v = value.toLowerCase().trim();
    if (v === "visible")
        return "visible";
    if (v === "hidden")
        return "hidden";
    return "unclear";
}
function coerceSimpleBackground(value) {
    if (typeof value !== "string")
        return "unclear";
    const v = value.toLowerCase().trim();
    if (v === "simple")
        return "simple";
    if (v === "busy")
        return "busy";
    return "unclear";
}
function parseVisibleFacts(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        return { ...DEFAULT_VISIBLE_FACTS };
    }
    const p = raw;
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
        color_palette_summary: typeof p.color_palette_summary === "string" ? p.color_palette_summary : null,
        silhouette_read: typeof p.silhouette_read === "string" ? p.silhouette_read : null,
        background_simple_or_busy: coerceSimpleBackground(p.background_simple_or_busy),
        lighting_quality: typeof p.lighting_quality === "string" ? p.lighting_quality : null,
        outfit_visibility_quality: typeof p.outfit_visibility_quality === "string" ? p.outfit_visibility_quality : null,
    };
}
function stripMarkdownFences(text) {
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
function extractJSONObjectSegment(text) {
    const firstBrace = text.indexOf("{");
    const lastBrace = text.lastIndexOf("}");
    if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
        return null;
    }
    return text.slice(firstBrace, lastBrace + 1);
}
function parseSingleCombinedResponse(raw, runId) {
    let cleaned = stripMarkdownFences(raw);
    let parsed;
    try {
        parsed = JSON.parse(cleaned);
    }
    catch (err) {
        const segment = extractJSONObjectSegment(cleaned);
        if (!segment) {
            console.log(`${LOG_PREFIX} parseSingleCombinedResponse: no JSON segment found`, {
                runId,
            });
            return null;
        }
        try {
            parsed = JSON.parse(segment);
        }
        catch (err2) {
            console.log(`${LOG_PREFIX} parseSingleCombinedResponse: JSON parse failed`, {
                runId,
                message: err2 instanceof Error ? err2.message : String(err2),
            });
            return null;
        }
    }
    // Some models may nest the payload under "analysis" or use visibleFacts instead of visible_facts.
    let root = parsed;
    let visibleFactsRaw = parsed.visible_facts ??
        parsed.visibleFacts;
    if (!visibleFactsRaw && parsed.analysis && typeof parsed.analysis === "object") {
        root = parsed.analysis;
        visibleFactsRaw =
            root.visible_facts ??
                root.visibleFacts;
    }
    let visibleFacts = { ...DEFAULT_VISIBLE_FACTS };
    let visibleFactsFromFallback = true;
    if (visibleFactsRaw) {
        let candidate = visibleFactsRaw;
        if (typeof visibleFactsRaw === "string") {
            try {
                candidate = JSON.parse(visibleFactsRaw);
            }
            catch {
                candidate = null;
            }
        }
        if (candidate && typeof candidate === "object" && !Array.isArray(candidate)) {
            visibleFacts = parseVisibleFacts(candidate);
            visibleFactsFromFallback = false;
        }
    }
    const arr = (key) => {
        const rootValue = root[key];
        if (Array.isArray(rootValue))
            return rootValue.map(String);
        const topValue = parsed[key];
        if (Array.isArray(topValue))
            return topValue.map(String);
        return [];
    };
    const result = {
        visibleFacts,
        visibleFactsFromFallback,
        strengths: arr("strengths"),
        improvements: arr("improvements"),
        suggestions: arr("suggestions"),
        analysisTips: arr("analysisTips"),
        improvementSuggestions: arr("improvementSuggestions"),
    };
    console.log(`${LOG_PREFIX} parseSingleCombinedResponse: parsed structure`, {
        runId,
        has_visible_facts: !visibleFactsFromFallback,
        strengths_raw_count: result.strengths.length,
        improvements_raw_count: result.improvements.length,
        suggestions_raw_count: result.suggestions.length,
    });
    return result;
}
function classifyEvaluability(facts) {
    if (!facts.person_visible)
        return "unevaluable";
    const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
    const crop = facts.body_crop_type;
    if (visibility.includes("hard to see") ||
        visibility.includes("very limited") ||
        visibility.includes("cannot see") ||
        visibility.includes("barely") ||
        visibility.includes("poor") ||
        visibility.includes("unclear")) {
        return "unevaluable";
    }
    if (visibility.includes("partially") ||
        visibility.includes("some parts") ||
        crop === "close_crop" ||
        crop === "mid_body") {
        return "limited_but_usable";
    }
    return "clearly_evaluable";
}
/** Weights: fit+proportion 60%, color 25%, occasion 10%, photo clarity 5%. Outfit quality drives the score; photo has minimal impact. */
const SUBSCORE_WEIGHTS = {
    composition: 0.60, // fit/tailoring (40%) + proportion/silhouette (20%) — combined as primary
    presentation: 0.25, // color coordination and palette balance
    purposeFit: 0.10, // style cohesion and occasion appropriateness
    lighting: 0.05, // photo clarity only; do not penalize if outfit is visible
};
/** Compute overall score from weighted subscores. Outfit (composition, presentation, purposeFit) dominates; lighting is minimal. */
function overallFromSubscores(subscores) {
    const weighted = subscores.composition * SUBSCORE_WEIGHTS.composition +
        subscores.presentation * SUBSCORE_WEIGHTS.presentation +
        subscores.purposeFit * SUBSCORE_WEIGHTS.purposeFit +
        subscores.lighting * SUBSCORE_WEIGHTS.lighting;
    return roundToOneDecimal(weighted);
}
const SUBSCORE_LABELS = {
    composition: "fit & proportion",
    lighting: "photo clarity",
    presentation: "color coordination",
    purposeFit: "occasion fit",
};
/** One-sentence explanation from subscores: highlight strongest and weakest dimensions. */
function deriveScoreExplanation(subscores) {
    const entries = ["composition", "lighting", "presentation", "purposeFit"].map((k) => [k, subscores[k]]);
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
function clampSubscoreToUserRange(value) {
    // Allow a wider spread similar to the earlier app feel:
    // very weak looks can dip toward mid-3s, strong looks can approach mid/high-9s,
    // but we still avoid extreme 0/10 style scores.
    const clamped = Math.min(9.4, Math.max(3.5, value));
    return roundToOneDecimal(clamped);
}
function deriveCompositionScore(facts) {
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
    }
    else if (facts.body_crop_type === "mid_body") {
        score -= 0.3;
    }
    // Clear waist definition usually strengthens silhouette.
    if (facts.waist_definition_visible === true) {
        score += 0.7;
    }
    else if (facts.waist_definition_visible === false) {
        score -= 0.3;
    }
    const silhouette = (facts.silhouette_read ?? "").toLowerCase();
    if (silhouette.includes("streamlined") ||
        silhouette.includes("balanced") ||
        silhouette.includes("clean") ||
        silhouette.includes("sharp")) {
        score += 0.9;
    }
    else if (silhouette.includes("boxy") ||
        silhouette.includes("wide") ||
        silhouette.includes("bulky") ||
        silhouette.includes("shapeless") ||
        silhouette.includes("sloppy")) {
        score -= 1.0;
    }
    // Fit descriptors: fitted vs relaxed/oversized.
    if (facts.top_fit === "fitted") {
        score += 0.4;
    }
    else if (facts.top_fit === "oversized" && !silhouette.includes("intentional")) {
        score -= 0.5;
    }
    if (facts.bottom_fit === "fitted") {
        score += 0.3;
    }
    else if (facts.bottom_fit === "oversized" && !silhouette.includes("intentional")) {
        score -= 0.3;
    }
    // Hoodie / sweatpant combos should realistically score lower on composition.
    const topType = (facts.top_type ?? "").toLowerCase();
    const bottomType = (facts.bottom_type ?? "").toLowerCase();
    const isHoodie = topType.includes("hoodie") || topType.includes("hooded") || topType.includes("sweatshirt");
    const isSweatpants = bottomType.includes("sweatpant") || bottomType.includes("jogger") || bottomType.includes("track");
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
    if ((facts.top_fit === "oversized" || facts.top_fit === "relaxed") &&
        (facts.bottom_fit === "oversized" || facts.bottom_fit === "relaxed") &&
        (silhouette.includes("boxy") || silhouette.includes("wide") || silhouette.includes("shapeless"))) {
        score -= 0.5;
    }
    return clampSubscoreToUserRange(score);
}
function deriveLightingScore(facts) {
    // Lighting: photo clarity only. Keep this relatively high and low-impact.
    let score = 7.4;
    const visibility = (facts.outfit_visibility_quality ?? "").toLowerCase();
    if (visibility.includes("hard") || visibility.includes("poor") || visibility.includes("unclear")) {
        score -= 0.8;
    }
    const lighting = (facts.lighting_quality ?? "").toLowerCase();
    if (lighting.includes("dim") || lighting.includes("harsh") || lighting.includes("backlit")) {
        score -= 0.6;
    }
    else if (lighting.includes("even") || lighting.includes("soft") || lighting.includes("natural")) {
        score += 0.3;
    }
    return clampSubscoreToUserRange(score);
}
function derivePresentationScore(facts) {
    // Presentation: palette cohesion, accessories, background impact.
    let score = 6.5;
    const palette = (facts.color_palette_summary ?? "").toLowerCase();
    if (palette.includes("cohesive") ||
        palette.includes("harmonious") ||
        palette.includes("monochrome") ||
        palette.includes("tonal")) {
        score += 0.9;
    }
    else if (palette.includes("clash") ||
        palette.includes("busy") ||
        palette.includes("chaotic") ||
        palette.includes("muddy")) {
        score -= 1.0;
    }
    const accessoriesText = (facts.accessory_summary ?? "").toLowerCase();
    const hasAccessories = facts.bracelets_visible === true ||
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
function derivePurposeFitScore(facts, purpose, composition, presentation) {
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
        if (silhouette.includes("boxy") ||
            silhouette.includes("sloppy") ||
            facts.top_fit === "oversized" ||
            facts.bottom_fit === "oversized") {
            score -= 0.7;
        }
        if (palette.includes("cohesive") || palette.includes("neutral") || palette.includes("tonal")) {
            score += 0.5;
        }
    }
    else if (purpose === "dating" || purpose === "social") {
        // For dating/social, cohesive or intentional color and a clean silhouette can push purposeFit up.
        if (silhouette.includes("streamlined") ||
            silhouette.includes("balanced") ||
            silhouette.includes("clean")) {
            score += 0.5;
        }
        if (palette.includes("cohesive") || palette.includes("harmonious") || palette.includes("bold")) {
            score += 0.4;
        }
    }
    else if (purpose === "compare") {
        if (facts.body_crop_type === "close_crop" || facts.body_crop_type === "unclear") {
            score -= 0.7;
        }
    }
    return clampSubscoreToUserRange(score);
}
function deriveSubscoresFromFacts(facts, purpose) {
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
/** Substrings that indicate feedback is about background/framing/lighting/photo rather than the outfit. */
const BACKGROUND_FOCUSED_PATTERNS = [
    "cleaner background", "simpler background", "less cluttered background", "clearer background",
    "better background", "neutral background", "plain background", "uncluttered background",
    "better framing", "improve framing", "tighter framing", "framing could", "crop the",
    "crop image", "crop the image", "cropping the image",
    "improve lighting", "better lighting", "lighting could", "softer lighting", "natural lighting",
    "photo could", "picture could", "shot could", "camera angle", "try a different angle",
    "step back", "zoom out", "full body shot", "better photo", "retake", "take another",
    "background is", "background distracts", "busy background", "cluttered background",
    "framing is", "lighting is", "too dark", "too bright", "backlit", "shadow",
    "upside down", "image is upside down", "rotate the image", "rotate the photo", "image orientation",
    "visual distractions", "reduce distractions", "photo clarity", "composition of the photo",
    "negative space", "too much negative space", "unbalanced composition", "composition is unbalanced",
    "position yourself centrally", "position yourself in the center", "center of the frame", "central in the frame",
    "lighting is uneven", "image is dark", "photo is dark", "partially dark",
];
/** Hard banned photo/scene critique phrases; these should never appear in outfit feedback sections. */
const PHOTO_CRITIQUE_PATTERNS = [
    "image is upside down",
    "upside down",
    "rotate the image",
    "rotate the photo",
    "rotation of the image",
    "image orientation",
    "rotate for better viewing",
    "crop the image",
    "crop image",
    "cropping the image",
    "better framing",
    "improve framing",
    "framing of the photo",
    "cleaner background",
    "simpler background",
    "cluttered background",
    "background is slightly cluttered",
    "room distractions",
    "scenery distractions",
    "visual distractions",
    "reduce distractions",
    "improve lighting",
    "enhance lighting",
    "lighting is flat",
    "lighting is shadowed",
    "lighting is too dark",
    "lighting is too bright",
    "photo clarity",
    "better camera angle",
    "camera angle",
    "composition of the photo",
    "composition is unbalanced",
    "unbalanced composition",
    "too much negative space",
    "negative space",
    "position yourself centrally",
    "position yourself in the center",
    "center of the frame",
    "central in the frame",
    "lighting is uneven",
    "image is dark",
    "photo is dark",
    "image is partially dark",
    "photo is partially dark",
    "soft light source",
    "softer light source",
    "fill light",
    "improve clarity",
    "better clarity",
    "highlight the outfit better",
    "focus more on the outfit",
];
/** True when feedback text is clearly about photo/background/lighting and should be blocked from outfit sections. */
function isPhotoCritiqueFeedback(text) {
    const n = normalizeForDedupe(text);
    for (const pattern of PHOTO_CRITIQUE_PATTERNS) {
        if (n.includes(pattern))
            return true;
    }
    return false;
}
/** True when the feedback text is primarily about background, framing, lighting, or photo setup (not the outfit). */
function isBackgroundFocusedFeedback(text) {
    const n = normalizeForDedupe(text);
    for (const pattern of BACKGROUND_FOCUSED_PATTERNS) {
        if (n.includes(pattern))
            return true;
    }
    const words = n.split(/\s+/);
    const backgroundWords = ["background", "framing", "lighting", "photo", "camera", "shot", "angle", "clutter", "cluttered"];
    const count = words.filter((w) => backgroundWords.some((b) => w.includes(b))).length;
    if (count >= 2)
        return true;
    if (words.length <= 6 && count >= 1 && !n.includes("outfit") && !n.includes("fit") && !n.includes("color") && !n.includes("silhouette"))
        return true;
    return false;
}
/** True when visible_facts indicate the outfit is hard to evaluate (poor visibility). */
function isOutfitVisibilityPoor(facts) {
    const v = (facts.outfit_visibility_quality ?? "").toLowerCase();
    return (v.includes("hard") ||
        v.includes("poor") ||
        v.includes("unclear") ||
        v.includes("limited") ||
        v.includes("barely") ||
        v.includes("cannot see") ||
        v.includes("parse_failed"));
}
/** Remove background/framing/lighting-focused items when the outfit is clearly visible. */
function dropBackgroundFocusedWhenVisible(items, facts) {
    if (isOutfitVisibilityPoor(facts))
        return items;
    return items.filter((s) => {
        const drop = isBackgroundFocusedFeedback(s);
        if (drop && ANALYSIS_DEBUG_ENABLED) {
            console.log(`${LOG_PREFIX} dropped background-focused feedback (outfit clearly visible)`, { text: s });
        }
        return !drop;
    });
}
function normalizeForDedupe(s) {
    return s.toLowerCase().replace(/\s+/g, " ").trim();
}
function isGeneric(text, debugContext) {
    const n = normalizeForDedupe(text);
    let reason = null;
    if (n.length < MIN_FEEDBACK_ITEM_LENGTH) {
        reason = "too_short";
    }
    else if (GENERIC_PHRASES.has(n)) {
        reason = "generic_phrase_exact";
    }
    else if (GENERIC_PHRASES.has(n.replace(/\.$/, ""))) {
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
function contentWords(s) {
    return normalizeForDedupe(s)
        .replace(/[^\w\s]/g, " ")
        .split(/\s+/)
        .filter((w) => w.length > 2);
}
/** True if the suggestion is just restating an improvement (same concept, no concrete actionable step). */
function isSuggestionRedundant(suggestion, improvements) {
    const sNorm = normalizeForDedupe(suggestion);
    const sWords = contentWords(suggestion);
    const hasActionable = sWords.some((w) => ACTIONABLE_INDICATORS.has(w));
    if (hasActionable && sWords.length >= 6)
        return false;
    for (const imp of improvements) {
        const iNorm = normalizeForDedupe(imp);
        if (sNorm === iNorm || sNorm.includes(iNorm) || iNorm.includes(sNorm))
            return true;
        const iWords = contentWords(imp);
        const overlap = sWords.filter((w) => iWords.includes(w)).length;
        if (overlap >= 2 && sWords.length <= 10 && !hasActionable)
            return true;
    }
    return false;
}
/** Remove exact/substring duplicates and suggestions that only restate an improvement. */
function dropCrossSectionDuplicates(suggestions, improvements) {
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
function sanitizeFeedbackItems(items) {
    const seen = new Set();
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
/** Build the standard invalid AnalysisResponse (e.g. when person not visible). */
function buildInvalidValidationResponse(reason) {
    return {
        isValid: false,
        validationMessage: "This photo doesn't appear suitable for analysis.",
        reason,
        score: null,
        subscores: null,
        strengths: [],
        improvements: [],
        suggestions: [],
        analysisTips: [],
        improvementSuggestions: [],
    };
}
// --- Contradiction / sanity cleanup ---
function sanitizeContradictorySuggestions(facts, analysis) {
    const shouldDropTuckAdvice = facts.top_tucked === true;
    const braceletsPresent = facts.bracelets_visible === true || facts.watch_visible === true;
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
    const anyAccessoriesPresent = beltPresent ||
        braceletsPresent ||
        necklacePresent ||
        ringsPresent ||
        accessorySummary.length > 0;
    const originalImprovements = analysis.improvements;
    const originalSuggestions = analysis.suggestions;
    function keepItem(text) {
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
    const cleanedImprovementSuggestions = analysis.improvementSuggestions?.filter(keepItem) ?? analysis.improvementSuggestions;
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
        improvementSuggestions: cleanedImprovementSuggestions && cleanedImprovementSuggestions.length > 0
            ? cleanedImprovementSuggestions
            : analysis.improvementSuggestions,
    };
}
/**
 * Ensures the response always has the full shape expected by iOS: arrays are never undefined,
 * score/subscores present when valid. Prevents decode/render crashes from malformed success responses.
 */
function ensureCompleteResponse(r) {
    const strengths = Array.isArray(r.strengths) ? r.strengths : [];
    const improvements = Array.isArray(r.improvements) ? r.improvements : [];
    const suggestions = Array.isArray(r.suggestions) ? r.suggestions : [];
    const analysisTips = Array.isArray(r.analysisTips) ? r.analysisTips : [];
    const improvementSuggestions = Array.isArray(r.improvementSuggestions) ? r.improvementSuggestions : undefined;
    if (!r.isValid) {
        return {
            isValid: false,
            validationMessage: r.validationMessage != null ? String(r.validationMessage) : "This photo doesn't appear suitable for analysis.",
            reason: r.reason ?? "image_not_relevant",
            score: null,
            subscores: null,
            strengths: [],
            improvements: [],
            suggestions: [],
            analysisTips: [],
            improvementSuggestions: [],
        };
    }
    const subscores = r.subscores && typeof r.subscores === "object" && !Array.isArray(r.subscores)
        ? r.subscores
        : subscoresFromScore(6.5);
    const score = typeof r.score === "number" && !Number.isNaN(r.score) ? roundToOneDecimal(r.score) : overallFromSubscores(subscores);
    return {
        ...r,
        strengths,
        improvements,
        suggestions,
        analysisTips,
        improvementSuggestions: improvementSuggestions && improvementSuggestions.length > 0 ? improvementSuggestions : undefined,
        score,
        subscores,
        scoreExplanation: r.scoreExplanation ?? deriveScoreExplanation(subscores),
    };
}
async function analyzePhotoWithAI(imageBase64, purpose, runId) {
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) {
        console.log(`${LOG_PREFIX} Falling back to mock analysis: missing API key`);
        if (ANALYSIS_DEBUG_ENABLED) {
            console.log(`${LOG_PREFIX} debug: getFallbackMockResult() used due to missing API key`);
        }
        return ensureCompleteResponse(getFallbackMockResult());
    }
    const t0 = Date.now();
    console.log(`${LOG_PREFIX} request pipeline started`, { purpose, runId });
    try {
        const openai = new openai_1.default({ apiKey });
        const model = getModel();
        const tResize0 = Date.now();
        const compressedBase64 = await (0, imageUtils_1.resizeAndCompressImage)(imageBase64);
        const imagePreprocessMs = Date.now() - tResize0;
        console.log(`${LOG_PREFIX} phase image_preprocess_ms`, { imagePreprocessMs });
        const imageUrl = compressedBase64.startsWith("data:")
            ? compressedBase64
            : `data:image/jpeg;base64,${compressedBase64}`;
        const fingerprint = computeImageFingerprint(compressedBase64);
        const debugInfo = ANALYSIS_DEBUG_ENABLED
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
            console.log(`${LOG_PREFIX} cache hit: exact image fingerprint (bypassed for testing)`, {
                purpose,
            });
            console.log(`${LOG_PREFIX} cache bypassed for testing`, { kind: "exact" });
            if (debugInfo) {
                debugInfo.cacheHitType = "exact";
            }
        }
        // Single OpenAI round-trip: visible_facts + strengths/improvements/suggestions in one response.
        const fullAnalysisDetail = "low";
        const singleRequestMaxTokens = 350;
        const tOpenAI0 = Date.now();
        console.log(`${LOG_PREFIX} OpenAI single combined request started`, {
            model,
            purpose,
            detail: fullAnalysisDetail,
            max_tokens: singleRequestMaxTokens,
        });
        const completion = await withTimeout(openai.chat.completions.create({
            model,
            messages: [
                { role: "system", content: COMBINED_SINGLE_REQUEST_SYSTEM },
                {
                    role: "user",
                    content: [
                        { type: "image_url", image_url: { url: imageUrl, detail: fullAnalysisDetail } },
                        { type: "text", text: getCombinedUserPrompt(purpose) },
                    ],
                },
            ],
            response_format: { type: "json_object" },
            max_tokens: singleRequestMaxTokens,
        }), OPENAI_REQUEST_TIMEOUT_MS, "Single combined analysis");
        const openaiRequestMs = Date.now() - tOpenAI0;
        console.log(`${LOG_PREFIX} phase openai_request_ms`, { openaiRequestMs });
        const raw = completion.choices[0]?.message?.content;
        if (!raw || typeof raw !== "string") {
            console.log(`${LOG_PREFIX} single response missing or non-string`);
            throw new errors_1.InvalidAIResponseError("Empty or non-string AI response");
        }
        const tParse0 = Date.now();
        const parsedCombined = parseSingleCombinedResponse(raw, runId);
        const parseMs = Date.now() - tParse0;
        console.log(`${LOG_PREFIX} phase parse_ms`, { parseMs });
        let visibleFacts;
        let visibleFactsFromFallback;
        let strengths;
        let improvements;
        let suggestions;
        let analysisTips;
        let improvementSuggestions;
        if (parsedCombined) {
            visibleFacts = parsedCombined.visibleFacts;
            visibleFactsFromFallback = parsedCombined.visibleFactsFromFallback;
            strengths = parsedCombined.strengths;
            improvements = parsedCombined.improvements;
            suggestions = parsedCombined.suggestions;
            analysisTips = parsedCombined.analysisTips;
            improvementSuggestions = parsedCombined.improvementSuggestions;
        }
        else {
            visibleFacts = { ...DEFAULT_VISIBLE_FACTS, outfit_visibility_quality: "parse_failed" };
            visibleFactsFromFallback = true;
            strengths = [];
            improvements = [];
            suggestions = [];
            analysisTips = [];
            improvementSuggestions = [];
        }
        if (!visibleFacts.person_visible) {
            const totalRequestMs = Date.now() - t0;
            console.log(`${LOG_PREFIX} guardrail check: no person visible`, { purpose });
            console.log(`${LOG_PREFIX} phase total_request_ms`, { totalRequestMs });
            console.log(`${LOG_PREFIX} summary`, {
                total_request_ms: totalRequestMs,
                cache: "none",
                visible_facts_fallback: visibleFactsFromFallback,
                path: "invalid_no_person",
            });
            if (debugInfo) {
                debugInfo.phase1Rejected = true;
                debugInfo.phase1Reason = "no_person_detected";
                logDebugSnapshot("person_not_visible_rejected", debugInfo);
            }
            return buildInvalidValidationResponse("no_person_detected");
        }
        const derivedSubscores = visibleFactsFromFallback
            ? subscoresFromScore(6.5)
            : deriveSubscoresFromFacts(visibleFacts, purpose);
        const derivedScore = overallFromSubscores(derivedSubscores);
        console.log(`${LOG_PREFIX} derived scores from visible facts`, {
            purpose,
            subscores: derivedSubscores,
            score: derivedScore,
        });
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
        const allowNearDuplicateAnchor = !visibleFactsFromFallback &&
            (visibleFacts.outfit_visibility_quality ?? "").toLowerCase() !== "parse_failed";
        if (allowNearDuplicateAnchor) {
            const bestMatch = findBestCachedMatch(purpose, visibleFacts);
            if (bestMatch && bestMatch.similarity >= 0.95) {
                bestMatch.entry.lastUsedAt = Date.now();
                if (debugInfo) {
                    debugInfo.cacheHitType = "near_duplicate";
                    debugInfo.cacheAnchorSimilarity = bestMatch.similarity;
                }
                console.log(`${LOG_PREFIX} near-duplicate cache hit (bypassed for testing)`, {
                    purpose,
                    similarity: bestMatch.similarity,
                });
                console.log(`${LOG_PREFIX} cache bypassed for testing`, { kind: "near_duplicate" });
            }
        }
        console.log(`${LOG_PREFIX} feedback counts before filtering`, {
            purpose,
            visible_facts_fallback: visibleFactsFromFallback,
            strengths_raw: strengths.length,
            improvements_raw: improvements.length,
            suggestions_raw: suggestions.length,
        });
        const strengthsSanitized = sanitizeFeedbackItems(strengths);
        const improvementsSanitized = sanitizeFeedbackItems(improvements);
        const suggestionsSanitized = sanitizeFeedbackItems(suggestions);
        let strengthsFiltered = strengthsSanitized.filter((s) => !isGeneric(s, { section: "strengths", runId: debugInfo?.fingerprint }));
        let improvementsFiltered = improvementsSanitized.filter((s) => !isGeneric(s, { section: "improvements", runId: debugInfo?.fingerprint }));
        let suggestionsFiltered = suggestionsSanitized.filter((s) => !isGeneric(s, { section: "suggestions", runId: debugInfo?.fingerprint }));
        suggestionsFiltered = dropCrossSectionDuplicates(suggestionsFiltered, improvementsFiltered);
        const analysisTipsSanitized = sanitizeFeedbackItems(analysisTips);
        let improvementSuggestionsSanitized = sanitizeFeedbackItems(improvementSuggestions).slice(0, 5);
        // HARD filter: never allow photo/scene critique phrases in outfit feedback sections.
        strengthsFiltered = strengthsFiltered.filter((s) => !isPhotoCritiqueFeedback(s));
        improvementsFiltered = improvementsFiltered.filter((s) => !isPhotoCritiqueFeedback(s));
        suggestionsFiltered = suggestionsFiltered.filter((s) => !isPhotoCritiqueFeedback(s));
        improvementSuggestionsSanitized = improvementSuggestionsSanitized.filter((s) => !isPhotoCritiqueFeedback(s));
        // When outfit is clearly visible, additionally strip background/framing/lighting-focused feedback from all sections.
        strengthsFiltered = dropBackgroundFocusedWhenVisible(strengthsFiltered, visibleFacts);
        improvementsFiltered = dropBackgroundFocusedWhenVisible(improvementsFiltered, visibleFacts);
        suggestionsFiltered = dropBackgroundFocusedWhenVisible(suggestionsFiltered, visibleFacts);
        improvementSuggestionsSanitized = dropBackgroundFocusedWhenVisible(improvementSuggestionsSanitized, visibleFacts);
        console.log(`${LOG_PREFIX} feedback counts after filtering`, {
            purpose,
            visible_facts_fallback: visibleFactsFromFallback,
            strengths_filtered: strengthsFiltered.length,
            improvements_filtered: improvementsFiltered.length,
            suggestions_filtered: suggestionsFiltered.length,
        });
        // Visibility comments are only appropriate when the outfit is genuinely hard to judge, and belong in analysisTips.
        const analysisTipsVisibilityFiltered = analysisTipsSanitized.filter((s) => {
            if (!isPhotoCritiqueFeedback(s))
                return true;
            return isOutfitVisibilityPoor(visibleFacts);
        });
        const analysisTipsFinal = isOutfitVisibilityPoor(visibleFacts) ? analysisTipsVisibilityFiltered : [];
        // If the outfit is evaluable but all sections are empty after filtering, provide conservative outfit-only fallbacks.
        const evaluability = classifyEvaluability(visibleFacts);
        if (evaluability !== "unevaluable") {
            const allEmpty = strengthsFiltered.length === 0 &&
                improvementsFiltered.length === 0 &&
                suggestionsFiltered.length === 0;
            if (allEmpty) {
                const fallbackStrengths = [];
                const fallbackImprovements = [];
                const fallbackSuggestions = [];
                const silhouetteText = (visibleFacts.silhouette_read ?? "").toLowerCase();
                const paletteText = (visibleFacts.color_palette_summary ?? "").toLowerCase();
                const topFit = visibleFacts.top_fit;
                const bottomFit = visibleFacts.bottom_fit;
                // Strengths: simple, outfit-only positives based on silhouette and palette.
                if (silhouetteText.includes("streamlined") ||
                    silhouetteText.includes("balanced") ||
                    silhouetteText.includes("clean")) {
                    fallbackStrengths.push("The overall silhouette reads clean and balanced.");
                }
                else if (topFit === "fitted" || bottomFit === "fitted") {
                    fallbackStrengths.push("There is a clear fitted element that helps define your shape.");
                }
                else {
                    fallbackStrengths.push("The outfit presents a relaxed, easygoing silhouette.");
                }
                if (paletteText.includes("cohesive") ||
                    paletteText.includes("harmonious") ||
                    paletteText.includes("tonal") ||
                    paletteText.includes("monochrome") ||
                    paletteText.includes("neutral")) {
                    fallbackStrengths.push("The color palette feels cohesive and intentional.");
                }
                // Improvements: gentle, outfit-focused opportunities.
                if (silhouetteText.includes("boxy") ||
                    silhouetteText.includes("wide") ||
                    silhouetteText.includes("shapeless")) {
                    fallbackImprovements.push("A bit more shape or structure could help the silhouette feel more intentional.");
                }
                else if (topFit === "oversized" || bottomFit === "oversized") {
                    fallbackImprovements.push("Balancing the relaxed fit with one more defined piece could sharpen the look.");
                }
                else {
                    fallbackImprovements.push("Clarifying the overall shape a touch more could make the outfit feel more put-together.");
                }
                // Suggestions: a single conservative styling nudge.
                fallbackSuggestions.push("Consider a small styling tweak, like refining proportions or adding a subtle styling detail, to make the outfit feel more intentional.");
                strengthsFiltered = fallbackStrengths;
                improvementsFiltered = fallbackImprovements;
                suggestionsFiltered = fallbackSuggestions;
            }
        }
        const factDrivenResult = {
            isValid: true,
            validationMessage: null,
            reason: null,
            score: derivedScore,
            subscores: derivedSubscores,
            scoreExplanation: deriveScoreExplanation(derivedSubscores),
            strengths: strengthsFiltered,
            improvements: improvementsFiltered.length > 0 ? improvementsFiltered : [],
            suggestions: suggestionsFiltered,
            analysisTips: analysisTipsFinal,
            improvementSuggestions: improvementSuggestionsSanitized.length > 0 ? improvementSuggestionsSanitized : undefined,
        };
        const sanitized = sanitizeContradictorySuggestions(visibleFacts, factDrivenResult);
        const completeSanitized = ensureCompleteResponse(sanitized);
        putCachedAnalysis(fingerprint, purpose, visibleFacts, completeSanitized);
        if (debugInfo) {
            debugInfo.finalStrengths = completeSanitized.strengths;
            debugInfo.finalImprovements = completeSanitized.improvements;
            debugInfo.finalSuggestions = completeSanitized.suggestions;
            debugInfo.finalAnalysisTips = completeSanitized.analysisTips;
            debugInfo.finalScore = completeSanitized.score;
            logDebugSnapshot("final_sanitized_output", debugInfo);
        }
        let finalResponse = completeSanitized;
        if (ANALYSIS_DEBUG_ENABLED && debugInfo) {
            finalResponse = {
                ...completeSanitized,
                debug: {
                    visibleFactsSummary: debugInfo.visibleFactsSummary ?? null,
                    evaluability: debugInfo.evaluability ?? null,
                    visibleFactsFromFallback: debugInfo.visibleFactsFromFallback ?? false,
                    strengthsCount: completeSanitized.strengths.length,
                    improvementsCount: completeSanitized.improvements.length,
                    suggestionsCount: completeSanitized.suggestions.length,
                },
            };
        }
        const totalRequestMs = Date.now() - t0;
        console.log(`${LOG_PREFIX} final score summary`, {
            purpose,
            subscores: finalResponse.subscores,
            score: finalResponse.score,
            fromVisibleFactsFallback: visibleFactsFromFallback,
            cacheHitType: debugInfo?.cacheHitType ?? "none",
        });
        console.log(`${LOG_PREFIX} analysis complete`, { purpose, score: finalResponse.score });
        console.log(`${LOG_PREFIX} phase total_request_ms`, { totalRequestMs });
        console.log(`${LOG_PREFIX} summary`, {
            total_request_ms: totalRequestMs,
            cache: "none",
            visible_facts_fallback: visibleFactsFromFallback,
            path: "success",
        });
        return finalResponse;
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
