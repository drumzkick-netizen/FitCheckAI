//
//  APIPhotoAnalysisService.swift
//  FitCheckAI
//

import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

enum AnalysisServiceError: LocalizedError {
    case invalidURL
    case connectionFailed(customMessage: String? = nil)
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingFailed
    /// Local network permission denied (e.g. URLError -1009 "Local network prohibited") on device.
    case localNetworkProhibited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .connectionFailed(let customMessage):
            return customMessage ?? "Unable to connect to analysis server."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let statusCode):
            return "Server error (status \(statusCode))."
        case .decodingFailed:
            return "Invalid response format."
        case .localNetworkProhibited:
            return "Local network access is blocked."
        }
    }
}

final class APIPhotoAnalysisService: PhotoAnalysisServicing {
    private let analyzeURLString: String
    private let session: URLSession

    /// Timeout for /analyze-photo (image + AI can be slow). Default URLSession is 60s; use longer for dev.
    private static let analyzeRequestTimeout: TimeInterval = 120

    init(session: URLSession = .shared) {
        self.analyzeURLString = AppConfig.analyzePhotoURL
        self.session = session
        print("[APIPhotoAnalysisService] Init — resolved analyze URL: \(analyzeURLString)")
    }

    func analyzePhoto(
        imageData: Data,
        purpose: PhotoPurpose
    ) async throws -> AnalysisOutcome {
        let runId = UUID().uuidString
        print("🔥🔥🔥 APIPhotoAnalysisService analyzePhoto — service entry (runId=\(runId))")
        guard let url = URL(string: analyzeURLString) else {
            print("[APIPhotoAnalysisService] Error: invalid URL")
            throw AnalysisServiceError.invalidURL
        }

        let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: imageData)
        let fingerprint = Self.imageFingerprint(for: preparedData)
        #if canImport(UIKit)
        let pixelSize: String
        if let image = UIImage(data: preparedData) {
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)
            pixelSize = "\(width)x\(height)"
        } else {
            pixelSize = "unknown"
        }
        #else
        let pixelSize = "unknown"
        #endif

        let base64String = preparedData.base64EncodedString()
        let body = AnalyzePhotoRequestDTO(
            imageBase64: base64String,
            purpose: purpose.rawValue
        )
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(runId, forHTTPHeaderField: "X-Fitcheck-Run-Id")
        request.timeoutInterval = Self.analyzeRequestTimeout
        request.httpBody = bodyData

        let requestURL = request.url?.absoluteString ?? "nil"
        print("[APIPhotoAnalysisService] REQUEST (runId=\(runId)) — URL: \(requestURL)")
        print("[APIPhotoAnalysisService] REQUEST (runId=\(runId)) — method: \(request.httpMethod ?? "nil"), timeout: \(request.timeoutInterval)s")
        print("[APIPhotoAnalysisService] REQUEST (runId=\(runId)) — preparedImage bytes: \(preparedData.count), pixelSize: \(pixelSize), fingerprint: \(fingerprint)")
        print("[APIPhotoAnalysisService] REQUEST (runId=\(runId)) — payload size: \(bodyData.count) bytes, imageBase64 length: \(base64String.count), purpose: \(purpose.rawValue)")
        print("[APIPhotoAnalysisService] Connecting to: \(requestURL)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let urlError = error as? URLError
            let nsError = error as NSError
            let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            let desc = error.localizedDescription
            let underlyingDesc = underlying?.localizedDescription ?? ""

            print("[APIPhotoAnalysisService] REQUEST FAILED (runId=\(runId)) — error: \(desc)")
            if let u = urlError {
                print("[APIPhotoAnalysisService] REQUEST FAILED (runId=\(runId)) — URLError code: \(u.code.rawValue) (\(String(describing: u.code)))")
            }
            print("[APIPhotoAnalysisService] REQUEST FAILED (runId=\(runId)) — underlying: \(String(describing: underlying))")

            let isLocalNetworkBlocked = (urlError?.code.rawValue == -1009)
                || desc.localizedCaseInsensitiveContains("Local network prohibited")
                || underlyingDesc.localizedCaseInsensitiveContains("Local network prohibited")
            if isLocalNetworkBlocked {
                print("[APIPhotoAnalysisService] REQUEST FAILED (runId=\(runId)) — Local network prohibited (code -1009). User must enable Local Network for FitCheckAI in Settings.")
                throw AnalysisServiceError.localNetworkProhibited
            }
            if urlError?.code.rawValue == -1004 {
                print("[APIPhotoAnalysisService] REQUEST FAILED (runId=\(runId)) — Could not connect to server (-1004). Is the backend running on port 3000?")
                throw AnalysisServiceError.connectionFailed(customMessage: "Could not reach the local backend. Make sure your backend server is running on port 3000.")
            }
            throw AnalysisServiceError.connectionFailed(customMessage: nil)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[APIPhotoAnalysisService] RESPONSE (runId=\(runId)) — invalid type (not HTTPURLResponse)")
            throw AnalysisServiceError.invalidResponse
        }

        print("[APIPhotoAnalysisService] RESPONSE (runId=\(runId)) — statusCode: \(httpResponse.statusCode), data length: \(data.count) bytes")

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyPreview = String(data: data, encoding: .utf8).map { $0.prefix(500) } ?? "nil"
            print("[APIPhotoAnalysisService] RESPONSE FAILED — statusCode: \(httpResponse.statusCode), body: \(bodyPreview)")
            throw AnalysisServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        let dto: AnalyzePhotoResponseDTO
        do {
            dto = try JSONDecoder().decode(AnalyzePhotoResponseDTO.self, from: data)
        } catch {
            let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(500)) } ?? "nil"
            print("[APIPhotoAnalysisService] DECODE FAILED (runId=\(runId)) — \(error.localizedDescription), raw body: \(bodyPreview)")
            throw AnalysisServiceError.decodingFailed
        }

        if !dto.isValid {
            let trimmed = dto.validationMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = trimmed.isEmpty ? "This photo doesn't appear suitable for analysis." : trimmed
            print("[APIPhotoAnalysisService] Validation failed (runId=\(runId)): \(dto.reason ?? "unknown")")
            return .invalid(message: message)
        }

        // For improve_fit, backend may return valid + improvementSuggestions without a score; use placeholder score so we can show suggestions.
        let score: Double
        if let s = dto.score {
            score = s
        } else if purpose == .improveFit, !(dto.improvementSuggestions ?? []).isEmpty {
            score = 7
            print("[APIPhotoAnalysisService] improve_fit (runId=\(runId)): valid response without score, using placeholder to show suggestions")
        } else {
            print("[APIPhotoAnalysisService] Error (runId=\(runId)): valid response but missing score")
            return .invalid(message: "We couldn't score this photo. Try another.")
        }

        let subscores: AnalysisSubscores? = dto.subscores.map {
            AnalysisSubscores(
                composition: $0.composition,
                lighting: $0.lighting,
                presentation: $0.presentation,
                purposeFit: $0.purposeFit
            )
        }
        let explanation = dto.scoreExplanation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explanationNilIfEmpty = explanation.map { $0.isEmpty ? nil : $0 } ?? nil
        let tips = (dto.analysisTips ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let improveSuggestions = (dto.improvementSuggestions ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let debugInfo: AnalysisDebugInfo?
        if let debugDTO = dto.debug {
            debugInfo = AnalysisDebugInfo(
                visibleFactsSummary: debugDTO.visibleFactsSummary,
                evaluability: debugDTO.evaluability,
                visibleFactsFromFallback: debugDTO.visibleFactsFromFallback ?? false,
                strengthsCount: debugDTO.strengthsCount,
                improvementsCount: debugDTO.improvementsCount,
                suggestionsCount: debugDTO.suggestionsCount
            )
            print("[APIPhotoAnalysisService] DEBUG (runId=\(runId)) — evaluability=\(debugDTO.evaluability ?? "nil"), fromFallback=\(debugDTO.visibleFactsFromFallback == true ? "true" : "false")")
        } else {
            debugInfo = nil
        }

        print("[APIPhotoAnalysisService] Decoding succeeded (runId=\(runId)) — score: \(score), strengths: \(dto.strengths.count), improvements: \(dto.improvements.count), suggestions: \(dto.suggestions.count)")
        print("[APIPhotoAnalysisService] FINAL (runId=\(runId)) — strengths: \(dto.strengths)")
        print("[APIPhotoAnalysisService] FINAL (runId=\(runId)) — improvements: \(dto.improvements)")
        print("[APIPhotoAnalysisService] FINAL (runId=\(runId)) — suggestions: \(dto.suggestions)")
        return .valid(AnalysisResult(
            score: score,
            subscores: subscores,
            strengths: dto.strengths,
            improvements: dto.improvements,
            suggestions: dto.suggestions,
            scoreExplanation: explanationNilIfEmpty,
            analysisTips: tips.isEmpty ? nil : tips,
            improvementSuggestions: improveSuggestions.isEmpty ? nil : improveSuggestions,
            debugInfo: debugInfo
        ))
    }

    private static func imageFingerprint(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(12))
    }
}
