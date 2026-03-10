"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const cors_1 = __importDefault(require("cors"));
const express_1 = __importDefault(require("express"));
const analyze_1 = require("./routes/analyze");
const app = (0, express_1.default)();
const PORT = process.env.PORT ?? 3000;
if (!process.env.OPENAI_API_KEY?.trim()) {
    console.warn("Warning: OPENAI_API_KEY is not set. Photo analysis requests will return fallback responses.");
}
app.use((0, cors_1.default)());
app.use(express_1.default.json({ limit: "20mb" }));
app.use((req, _res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
});
app.get("/health", (_req, res) => {
    res.status(200).send("ok");
});
app.post("/analyze-photo", analyze_1.analyzePhoto);
const HOST = "0.0.0.0";
app.listen(Number(PORT), HOST, () => {
    console.log(`FitCheck backend running at http://localhost:${PORT}`);
    console.log(`Listening on ${HOST} — reachable from other devices at http://<this-machine-lan-ip>:${PORT}`);
    console.log("POST /analyze-photo — imageBase64 + purpose → AI analysis (same response shape).");
});
