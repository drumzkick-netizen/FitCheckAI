//
//  AnalyzeView.swift
//  FitCheckAI
//

import SwiftUI

private let minAnalysisDisplayDuration: Double = 1.5
private let completionDelayBeforeNavigate: Double = 0.6

struct AnalyzeView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel: AnalyzeViewModel
    @State private var hasStartedAnalysis = false
    @State private var hasScheduledCompletionNavigation = false
    @State private var analysisStartTime: Date?
    @State private var minDisplaySatisfied = true

    init(service: PhotoAnalysisServicing) {
        _viewModel = StateObject(wrappedValue: AnalyzeViewModel(service: service))
    }

    private var hasOutcome: Bool {
        viewModel.result != nil || viewModel.errorMessage != nil || viewModel.validationErrorMessage != nil
    }

    private var showLoadingState: Bool {
        viewModel.isLoading || (hasOutcome && !minDisplaySatisfied)
    }

    /// Invalid-photo state: backend returned isValid = false. Show dedicated screen only; do not stack with analyze content.
    private var isInvalidPhotoState: Bool {
        viewModel.validationErrorMessage != nil && minDisplaySatisfied
    }

    var body: some View {
        Group {
            if isInvalidPhotoState, let message = viewModel.validationErrorMessage {
                invalidPhotoView(message: message)
            } else {
                analyzeContentView
            }
        }
        .background(AmbientGlowBackground())
        .navigationTitle(isInvalidPhotoState ? "Photo Not Usable" : "Analyze")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Start Over") {
                    startOver()
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
            }
        }
        .onAppear {
            #if DEBUG
            print("AnalyzeView onAppear — will tryAutoStartAnalysis if not invalid")
            #endif
            if !isInvalidPhotoState {
                tryAutoStartAnalysis()
            }
        }
        .onChange(of: viewModel.result) { _, newResult in
            if newResult != nil, !hasScheduledCompletionNavigation {
                scheduleCompletionOrMinDelay()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newMessage in
            if newMessage != nil {
                scheduleMinDisplayThenSatisfied()
            }
        }
        .onChange(of: viewModel.validationErrorMessage) { _, newMessage in
            if newMessage != nil {
                scheduleMinDisplayThenSatisfied()
            }
        }
    }

    // MARK: - Dedicated invalid-photo screen (replaces analyze content)

    private func invalidPhotoView(message: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            GlowCard(padding: 24, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Photo Not Usable")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppColors.mutedText)
                    Text("Try a clearer photo with your face or outfit visible.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText.opacity(0.9))
                    Button("Try Another Photo") {
                        tryAnotherPhoto()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Navigate back to capture so the user can pick another photo. Invalid result is not saved.
    private func tryAnotherPhoto() {
        viewModel.validationErrorMessage = nil
        while flowViewModel.navigationPath.count > 1 {
            flowViewModel.navigationPath.removeLast()
        }
    }

    // MARK: - Normal analyze flow content

    private var analyzeContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                heroSection
                statusSection
                if let errorMessage = viewModel.errorMessage, minDisplaySatisfied {
                    errorSection(message: errorMessage)
                }
                if viewModel.result != nil, minDisplaySatisfied {
                    completeSection
                }
                if showIdleState {
                    idleSection
                }
                Spacer(minLength: 80)
            }
            .appScreenContent()
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
    }

    private var headerSection: some View {
        Group {
            if showLoadingState {
                Text(viewModel.statusLine ?? "Analyzing your fit...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            } else if !showIdleState {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analyzing Your Photo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Reviewing your photo for the best feedback.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    private var showIdleState: Bool {
        !viewModel.isLoading && viewModel.result == nil && viewModel.errorMessage == nil
            && viewModel.validationErrorMessage == nil
            && (flowViewModel.selectedImageData == nil || flowViewModel.selectedPurpose == nil)
    }

    private var heroSection: some View {
        VStack(spacing: 24) {
            if let image = flowViewModel.selectedImage {
                ScanningPhotoView(image: image, isAnimating: showLoadingState)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            if let purpose = flowViewModel.selectedPurpose {
                HStack(spacing: 8) {
                    Text(purpose.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.mutedText)
                    PurposeBadgeView(text: PurposeBadge.label(for: purpose))
                }
            }
        }
        .padding(.bottom, 28)
    }

    private var statusSection: some View {
        Group {
            if showLoadingState {
                AnalysisProgressView(
                    isComplete: Binding(
                        get: { hasOutcome },
                        set: { _ in }
                    )
                )
            } else if viewModel.result != nil {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.scoreHigh)
                    Text("Analysis complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(AppMotion.standardEase, value: showLoadingState)
    }

    private func errorSection(message: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Analysis Failed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
                Button("Try Again") {
                    #if DEBUG
                    print("AnalyzeView Try Again button tapped — calling runAnalysis")
                    #endif
                    viewModel.errorMessage = nil
                    runAnalysis()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, 24)
    }

    private var completeSection: some View {
        EmptyView()
    }

    private var idleSection: some View {
        VStack(spacing: 12) {
            Text("Add a photo and choose a mode to get your score.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func startOver() {
        flowViewModel.resetFlow()
        flowViewModel.requestedTabIndex = 0
    }

    private func scheduleMinDisplayThenSatisfied() {
        let start = analysisStartTime ?? Date()
        let elapsed = Date().timeIntervalSince(start)
        let remaining = max(0, minAnalysisDisplayDuration - elapsed)
        if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                minDisplaySatisfied = true
            }
        } else {
            minDisplaySatisfied = true
        }
    }

    private func scheduleCompletionOrMinDelay() {
        guard viewModel.result != nil, !hasScheduledCompletionNavigation else { return }
        hasScheduledCompletionNavigation = true
        let start = analysisStartTime ?? Date()
        let elapsed = Date().timeIntervalSince(start)
        let remaining = max(0, minAnalysisDisplayDuration - elapsed)
        let delayUntilSatisfied = remaining
        let delayUntilNavigate = remaining + completionDelayBeforeNavigate
        if delayUntilSatisfied > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayUntilSatisfied) {
                minDisplaySatisfied = true
            }
        } else {
            minDisplaySatisfied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delayUntilNavigate) {
            saveResultAndNavigate()
        }
    }

    private func tryAutoStartAnalysis() {
        guard flowViewModel.selectedImageData != nil,
              flowViewModel.selectedPurpose != nil,
              !viewModel.isLoading,
              viewModel.result == nil,
              viewModel.errorMessage == nil,
              viewModel.validationErrorMessage == nil,
              !hasStartedAnalysis else { return }
        print("Analyze tapped (auto-start on appear)")
        print("🔥🔥🔥 AnalyzeView tryAutoStartAnalysis — auto-starting analysis (onAppear path)")
        hasStartedAnalysis = true
        runAnalysis()
    }

    private func runAnalysis() {
        guard let imageData = flowViewModel.selectedImageData,
              let purpose = flowViewModel.selectedPurpose else { return }
        print("Analyze tapped — starting analysis")
        AnalyticsService.log(.analysisStarted)
        analysisStartTime = Date()
        minDisplaySatisfied = false
        hasScheduledCompletionNavigation = false
        Task { @MainActor in
            await viewModel.analyze(imageData: imageData, purpose: purpose)
        }
    }

    /// Only called when we have a valid result. Invalid analyses are never saved.
    private func saveResultAndNavigate() {
        guard let result = viewModel.result,
              let imageData = flowViewModel.selectedImageData,
              let purpose = flowViewModel.selectedPurpose else { return }
        subscriptionManager.recordAnalysisUsedIfNeeded()
        #if DEBUG
        print("Navigation to results triggered")
        #endif
        AnalyticsService.log(.analysisCompleted)
        flowViewModel.latestResult = result
        historyViewModel.addAnalysis(imageData: imageData, purpose: purpose, result: result)
        flowViewModel.navigationPath.append(.results)
    }
}

#Preview {
    NavigationStack {
        AnalyzeView(service: APIPhotoAnalysisService())
            .environmentObject(AppFlowViewModel())
            .environmentObject(HistoryViewModel())
    }
}
