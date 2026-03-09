"use strict";
/**
 * Resize and compress image for vision API to reduce payload size and token cost.
 * Uses sharp when available; returns original base64 on failure or if sharp is missing.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.resizeAndCompressImage = resizeAndCompressImage;
const MAX_DIMENSION = 1024;
const JPEG_QUALITY = 82;
function getBase64Data(imageBase64) {
    const trimmed = imageBase64.trim();
    const dataUrlPrefix = "data:";
    if (trimmed.toLowerCase().startsWith(dataUrlPrefix)) {
        const base64Part = trimmed.includes(",") ? trimmed.split(",")[1]?.trim() ?? trimmed : trimmed;
        return { buffer: Buffer.from(base64Part ?? "", "base64"), hadDataUrl: true };
    }
    return { buffer: Buffer.from(trimmed, "base64"), hadDataUrl: false };
}
/**
 * Resize image so the longest side is at most MAX_DIMENSION and re-encode as JPEG.
 * Returns base64 string (with optional data URL prefix to match input).
 * On any error (missing sharp, decode/encode failure), returns the original base64 unchanged.
 */
async function resizeAndCompressImage(imageBase64) {
    let sharp = null;
    try {
        sharp = require("sharp");
    }
    catch {
        return imageBase64;
    }
    const { buffer, hadDataUrl } = getBase64Data(imageBase64);
    if (buffer.length === 0)
        return imageBase64;
    try {
        const out = await sharp(buffer)
            .resize(MAX_DIMENSION, MAX_DIMENSION, { fit: "inside", withoutEnlargement: true })
            .jpeg({ quality: JPEG_QUALITY })
            .toBuffer();
        const b64 = out.toString("base64");
        return hadDataUrl ? `data:image/jpeg;base64,${b64}` : b64;
    }
    catch {
        return imageBase64;
    }
}
