//
//  AnalyzeViewModel.swift
//  FitCheckAI
//

import Combine
import Foundation

@MainActor
final class AnalyzeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var result: AnalysisResult?
    @Published var errorMessage: String?
    /// When the backend rejects the image (e.g. no person, outfit not visible). Do not show score; show "Photo Not Usable" UI.
    @Published var validationErrorMessage: String?
    /// Short status line shown while analysis is in progress (e.g. first attempt vs auto-retry).
    @Published var statusLine: String? = nil

    private let service: PhotoAnalysisServicing

    init(service: PhotoAnalysisServicing) {
        self.service = service
    }

    func analyze(imageData: Data, purpose: PhotoPurpose) async {
        print("Entering analyze method")
        errorMessage = nil
        validationErrorMessage = nil
        result = nil
        isLoading = true
        statusLine = "Starting analysis..."
        print("Loading state set")

        // First attempt
        do {
            print("[AnalyzeViewModel] First analysis attempt started")
            let outcome = try await service.analyzePhoto(imageData: imageData, purpose: purpose)
            print("[AnalyzeViewModel] First analysis attempt succeeded")
            isLoading = false
            statusLine = nil
            switch outcome {
            case .valid(let analysisResult):
                result = analysisResult
                validationErrorMessage = nil
                print("Result assigned")
            case .invalid(let message):
                result = nil
                validationErrorMessage = message
                print("Result assigned (invalid)")
            }
            return
        } catch {
            print("[AnalyzeViewModel] First analysis attempt failed: \(error)")
            if shouldAutoRetry(for: error) {
                // Auto-retry once after a short delay for transient connectivity/server issues.
                print("[AnalyzeViewModel] Scheduling automatic retry after transient failure")
                statusLine = "Waking up analysis server..."
                do {
                    try await Task.sleep(nanoseconds: 1_500_000_000) // ~1.5 seconds
                } catch {
                    // If sleep is interrupted, fall through to final failure handling.
                }

                do {
                    print("[AnalyzeViewModel] Automatic retry started")
                    statusLine = "Still working..."
                    let retryOutcome = try await service.analyzePhoto(imageData: imageData, purpose: purpose)
                    print("[AnalyzeViewModel] Automatic retry succeeded")
                    isLoading = false
                    statusLine = nil
                    switch retryOutcome {
                    case .valid(let analysisResult):
                        result = analysisResult
                        validationErrorMessage = nil
                        print("Result assigned (retry)")
                    case .invalid(let message):
                        result = nil
                        validationErrorMessage = message
                        print("Result assigned (invalid, retry)")
                    }
                    return
                } catch {
                    print("[AnalyzeViewModel] Automatic retry failed: \(error)")
                    // Fall through to final failure handling below.
                }
            }

            // Final failure after first attempt (non-retriable) or retry failure.
            print("Caught error: \(error)")
            print("Analysis failed: \(error.localizedDescription)")
            errorMessage = userFacingMessage(for: error)
            validationErrorMessage = nil
            isLoading = false
            statusLine = nil
        }
    }

    /// Decide whether we should perform a one-time automatic retry for a given error.
    private func shouldAutoRetry(for error: Error) -> Bool {
        guard let analysisError = error as? AnalysisServiceError else { return false }
        switch analysisError {
        case .connectionFailed:
            // Transient network/connectivity issue — good candidate for a quick retry.
            return true
        case .serverError(let statusCode):
            // Only retry once for typical transient server-side conditions.
            return [502, 503, 504].contains(statusCode)
        case .invalidURL, .invalidResponse, .decodingFailed, .localNetworkProhibited:
            return false
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let analysisError = error as? AnalysisServiceError {
            switch analysisError {
            case .localNetworkProhibited:
                return "Local network access is blocked. Enable Local Network permission for FitCheckAI in iPhone Settings to use your local development server."
            case .connectionFailed, .invalidURL:
                return "Unable to connect to analysis server."
            case .decodingFailed, .invalidResponse, .serverError:
                return "Received an invalid response from the server."
            }
        }
        return "Unable to connect to analysis server."
    }
}
