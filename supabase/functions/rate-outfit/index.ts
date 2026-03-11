import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const body = await req.json()

    const imageUrl = body.image_url ?? ""
    const description = body.description ?? ""

    if (!imageUrl && !description) {
      return new Response(
        JSON.stringify({ error: "No outfit data provided" }),
        { status: 400 }
      )
    }

    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")

    const prompt = `
You are a fashion evaluator.

Rate the outfit from 1-10.

Provide:
- overall score
- what works
- what could improve
- style category

Outfit description:
${description}

Image URL:
${imageUrl}
`

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [{ text: prompt }]
            }
          ]
        })
      }
    )

    const data = await response.json()

    const result =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "No response"

    return new Response(
      JSON.stringify({ result }),
      { headers: { "Content-Type": "application/json" } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})