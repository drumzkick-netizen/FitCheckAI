"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzePhoto = analyzePhoto;
const errors_1 = require("../errors");
const aiAnalysis_1 = require("../services/aiAnalysis");
const types_1 = require("../types");
const LOG_PREFIX = "[analyze-photo]";
function isDevelopment() {
    const env = process.env.NODE_ENV?.toLowerCase();
    return env === "development" || env === "dev";
}
/** Sanitize error for logging: no API keys or full request bodies. */
function safeErrorPayload(err) {
    if (!err || typeof err !== "object")
        return {};
    const o = err;
    const out = {};
    if (typeof o.status === "number")
        out.status = o.status;
    if (typeof o.statusCode === "number")
        out.statusCode = o.statusCode;
    if (typeof o.code === "string" && !/key|secret|token|auth/i.test(o.code))
        out.code = o.code;
    if (typeof o.message === "string")
        out.message = o.message;
    const errInner = o.error;
    if (errInner && typeof errInner.message === "string")
        out.errorMessage = errInner.message;
    return out;
}
async function analyzePhoto(req, res) {
    const body = req.body;
    const purpose = body?.purpose;
    const imageBase64 = body?.imageBase64;
    const imagePayloadLength = typeof imageBase64 === "string" ? imageBase64.length : 0;
    console.log(`${LOG_PREFIX} request received`, { purpose, imagePayloadLength });
    console.log(`${LOG_PREFIX} image validation started`);
    if (typeof imageBase64 !== "string" || imageBase64.trim().length === 0) {
        console.log(`${LOG_PREFIX} image validation failed: missing or invalid imageBase64`);
        res.status(400).json({
            error: "Missing or invalid imageBase64 (must be a non-empty string)",
            code: "invalid_request",
        });
        return;
    }
    if (!(0, types_1.isPhotoPurpose)(purpose)) {
        console.log(`${LOG_PREFIX} image validation failed: invalid purpose`);
        res.status(400).json({
            error: "Invalid purpose (must be one of: outfit, dating, social, professional, compare)",
            code: "invalid_request",
        });
        return;
    }
    console.log(`${LOG_PREFIX} image validation passed`);
    try {
        const analysis = await (0, aiAnalysis_1.analyzePhotoWithAI)(imageBase64, purpose);
        console.log(`${LOG_PREFIX} final response sent: success`);
        res.status(200).json(analysis);
    }
    catch (err) {
        const errName = err instanceof Error ? err.name : "Error";
        const errMessage = err instanceof Error ? err.message : String(err);
        const statusCode = err instanceof errors_1.OpenAIServiceError
            ? err.statusCode
            : "status" in err && typeof err.status === "number"
                ? err.status
                : undefined;
        console.error(`${LOG_PREFIX} request failed`, {
            errorName: errName,
            errorMessage: errMessage,
            statusCode: statusCode ?? "(none)",
            openaiPayload: err instanceof errors_1.OpenAIServiceError ? undefined : safeErrorPayload(err),
        });
        if (isDevelopment() && err instanceof Error && err.stack) {
            console.error(`${LOG_PREFIX} stack trace`, err.stack);
        }
        if (err instanceof errors_1.OpenAIServiceError) {
            console.log(`${LOG_PREFIX} final response sent: error`, { code: "openai_failed" });
            res.status(503).json({
                error: "Analysis service is temporarily unavailable. Please try again later.",
                code: "openai_failed",
            });
            return;
        }
        if (err instanceof errors_1.InvalidAIResponseError) {
            console.log(`${LOG_PREFIX} final response sent: error`, { code: "invalid_ai_response" });
            res.status(502).json({
                error: "Analysis could not be completed. Please try another photo.",
                code: "invalid_ai_response",
            });
            return;
        }
        const isNetworkOrUnavailable = err instanceof Error &&
            (errMessage.includes("ECONNREFUSED") ||
                errMessage.includes("ENOTFOUND") ||
                errMessage.includes("ETIMEDOUT") ||
                errMessage.includes("socket hang up"));
        if (isNetworkOrUnavailable) {
            console.log(`${LOG_PREFIX} final response sent: error`, { code: "backend_unavailable" });
            res.status(503).json({
                error: "Service temporarily unavailable. Please try again later.",
                code: "backend_unavailable",
            });
            return;
        }
        console.log(`${LOG_PREFIX} final response sent: error`, { code: "unknown" });
        res.status(500).json({
            error: "An unexpected error occurred. Please try again later.",
            code: "unknown",
        });
    }
}
