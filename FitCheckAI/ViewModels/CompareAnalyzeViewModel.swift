//
//  CompareAnalyzeViewModel.swift
//  FitCheckAI
//

import Combine
import Foundation

@MainActor
final class CompareAnalyzeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var firstResult: AnalysisResult?
    @Published var secondResult: AnalysisResult?
    @Published var winner: CompareWinner?
    @Published var errorMessage: String?

    private let service: PhotoAnalysisServicing

    init(service: PhotoAnalysisServicing) {
        self.service = service
    }

    func analyzeBoth(firstImageData: Data, secondImageData: Data) async {
        isLoading = true
        errorMessage = nil
        firstResult = nil
        secondResult = nil
        winner = nil

        do {
            let firstOutcome = try await service.analyzePhoto(imageData: firstImageData, purpose: .compare)
            guard case .valid(let first) = firstOutcome else {
                if case .invalid(let message) = firstOutcome {
                    errorMessage = message
                }
                isLoading = false
                return
            }
            firstResult = first

            let secondOutcome = try await service.analyzePhoto(imageData: secondImageData, purpose: .compare)
            guard case .valid(let second) = secondOutcome else {
                if case .invalid(let message) = secondOutcome {
                    errorMessage = message
                }
                firstResult = nil
                isLoading = false
                return
            }
            secondResult = second

            let diff = abs(first.score - second.score)
            if diff < 0.2 {
                winner = .tie
            } else if first.score > second.score {
                winner = .photoA
            } else {
                winner = .photoB
            }
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
        isLoading = false
    }

    private func userFacingMessage(for error: Error) -> String {
        if let analysisError = error as? AnalysisServiceError, case .localNetworkProhibited = analysisError {
            return "Local network access is blocked. Enable Local Network permission for FitCheckAI in iPhone Settings to use your local development server."
        }
        return "Unable to connect. Please try again."
    }
}
