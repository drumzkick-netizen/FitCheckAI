import Foundation

final class OutfitAIService: PhotoAnalysisServicing {
    private let baseURL = "https://afoupgcmxsmsazxkuyjg.functions.supabase.co/rate-outfit"

    func analyzePhoto(
        imageData: Data,
        purpose: PhotoPurpose
    ) async throws -> AnalysisOutcome {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }

        let base64 = imageData.base64EncodedString()

        let body: [String: Any] = [
            "description": "Purpose: \(purpose.rawValue)",
            "image_url": base64
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "OutfitAIService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: text
            ])
        }

        let decoded = try JSONDecoder().decode(OutfitAIResponse.self, from: data)
        let text = decoded.result.trimmingCharacters(in: .whitespacesAndNewlines)

        return .valid(
            AnalysisResult(
                score: 8.0,
                subscores: AnalysisSubscores(
                    composition: 8.0,
                    lighting: 8.0,
                    presentation: 8.0,
                    purposeFit: 8.0
                ),
                strengths: [text],
                improvements: [],
                suggestions: []
            )
        )
    }
}

private struct OutfitAIResponse: Decodable {
    let result: String
}