# FitCheck Backend

Minimal Node.js + Express + TypeScript backend for AI photo analysis.  
POST `/analyze-photo` accepts an image (base64) and purpose, returns structured analysis (score, strengths, improvements, suggestions).

## Install

```bash
npm install
```

## Environment (.env)

Create a `.env` file in the `backend` folder:

```env
OPENAI_API_KEY=your_openai_api_key_here
PORT=3000
```

Optional:

```env
OPENAI_MODEL=gpt-4o
```

If `OPENAI_API_KEY` is missing, the server still starts but analysis requests return a safe fallback response.

## Run

**Development (with auto-reload):**

```bash
npm run dev
```

**Production:**

```bash
npm run build
npm start
```

Server listens on `http://localhost:3000` (or the port in `PORT`).

## Request / payload

- **Endpoint:** `POST /analyze-photo`
- **Body (JSON):** `{ "imageBase64": "<base64 string>", "purpose": "outfit" | "dating" | "social" | "professional" | "compare" }`
- **Payload limit:** 10MB (for base64 images). Keep images reasonably sized (e.g. under ~2–3MB as file) to avoid timeouts.

## Response shape

Same for both success and fallback:

```json
{
  "score": 8.2,
  "strengths": ["...", "..."],
  "improvements": ["...", "..."],
  "suggestions": ["...", "..."]
}
```
