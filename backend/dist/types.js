"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isPhotoPurpose = isPhotoPurpose;
exports.isValidationReason = isValidationReason;
const VALID_PURPOSES = [
    "outfit",
    "dating",
    "social",
    "professional",
    "compare",
    "improve_fit",
];
function isPhotoPurpose(value) {
    return typeof value === "string" && VALID_PURPOSES.includes(value);
}
const VALID_REASONS = [
    "no_person_detected",
    "outfit_not_visible",
    "image_not_relevant",
    "framing_too_unclear",
];
function isValidationReason(value) {
    return typeof value === "string" && VALID_REASONS.includes(value);
}
