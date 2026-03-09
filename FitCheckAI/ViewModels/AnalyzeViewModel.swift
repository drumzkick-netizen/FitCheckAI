//
//  AnalyzeViewModel.swift
//  FitCheckAI
//

import Combine
import Foundation

final class AnalyzeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var result: AnalysisResult?
    @Published var errorMessage: String?
    /// When the backend rejects the image (e.g. no person, outfit not visible). Do not show score; show "Photo Not Usable" UI.
    @Published var validationErrorMessage: String?

    private let service: PhotoAnalysisServicing

    init(service: PhotoAnalysisServicing) {
        self.service = service
    }

    func analyze(imageData: Data, purpose: PhotoPurpose) async {
        print("🔥🔥🔥 AnalyzeViewModel analyze — view model entry, calling service.analyzePhoto")
        errorMessage = nil
        validationErrorMessage = nil
        result = nil
        isLoading = true

        do {
            let outcome = try await service.analyzePhoto(imageData: imageData, purpose: purpose)
            await MainActor.run {
                isLoading = false
                switch outcome {
                case .valid(let analysisResult):
                    result = analysisResult
                    validationErrorMessage = nil
                case .invalid(let message):
                    result = nil
                    validationErrorMessage = message
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = userFacingMessage(for: error)
                validationErrorMessage = nil
                isLoading = false
            }
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
