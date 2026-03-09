"use strict";
/**
 * Typed errors for /analyze-photo so the route can return appropriate status and client-safe codes.
 * Do not attach secrets or raw API payloads to these errors.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.InvalidAIResponseError = exports.OpenAIServiceError = void 0;
class OpenAIServiceError extends Error {
    constructor(message, statusCode) {
        super(message);
        this.statusCode = statusCode;
        this.name = "OpenAIServiceError";
        Object.setPrototypeOf(this, OpenAIServiceError.prototype);
    }
}
exports.OpenAIServiceError = OpenAIServiceError;
class InvalidAIResponseError extends Error {
    constructor(message = "Invalid AI response format") {
        super(message);
        this.name = "InvalidAIResponseError";
        Object.setPrototypeOf(this, InvalidAIResponseError.prototype);
    }
}
exports.InvalidAIResponseError = InvalidAIResponseError;
