import "dotenv/config";
import cors from "cors";
import express from "express";
import { analyzePhoto } from "./routes/analyze";

const app = express();
const PORT = process.env.PORT ?? 3000;

if (!process.env.OPENAI_API_KEY?.trim()) {
  console.warn("Warning: OPENAI_API_KEY is not set. Photo analysis requests will return fallback responses.");
}

app.use(cors());
app.use(express.json({ limit: "20mb" }));

app.use((req, _res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

app.get("/health", (_req, res) => {
  res.status(200).send("ok");
});

app.post("/analyze-photo", analyzePhoto);

const HOST = "0.0.0.0";
app.listen(Number(PORT), HOST, () => {
  console.log(`FitCheck backend running at http://localhost:${PORT}`);
  console.log(`Listening on ${HOST} — reachable from other devices at http://<this-machine-lan-ip>:${PORT}`);
  console.log("POST /analyze-photo — imageBase64 + purpose → AI analysis (same response shape).");
});
