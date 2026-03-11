//
//  CompareAnalyzeView.swift
//  FitCheckAI
//

import SwiftUI

private let minCompareDisplayDuration: Double = 1.5
private let compareLoadingMessages = [
    "Comparing both photos...",
    "Scoring Photo A...",
    "Scoring Photo B...",
    "Picking the stronger one...",
    "Finalizing result..."
]
private let compareLoadingMessageInterval: TimeInterval = 1.2

struct CompareAnalyzeView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @StateObject private var viewModel: CompareAnalyzeViewModel
    @State private var analysisStartTime: Date?
    @State private var hasScheduledNavigation = false
    @State private var loadingMessageIndex = 0
    @State private var loadingMessageTimer: Timer?

    init(service: PhotoAnalysisServicing) {
        _viewModel = StateObject(wrappedValue: CompareAnalyzeViewModel(service: service))
    }

    private var showLoadingState: Bool {
        viewModel.isLoading || (viewModel.winner != nil && !hasScheduledNavigation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                photosSection
                if showLoadingState {
                    loadingSection
                } else if let message = viewModel.errorMessage {
                    errorSection(message: message)
                } else if viewModel.winner != nil {
                    completeSection
                }
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Comparing Photos")
        .preferredColorScheme(.dark)
        .onAppear {
            guard let first = flowViewModel.selectedImageData,
                  let second = flowViewModel.compareImageData else { return }
            analysisStartTime = Date()
            hasScheduledNavigation = false
            loadingMessageIndex = 0
            startLoadingMessageTimer()
            Task {
                await viewModel.analyzeBoth(firstImageData: first, secondImageData: second)
            }
        }
        .onDisappear {
            stopLoadingMessageTimer()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if isLoading {
                loadingMessageIndex = 0
                startLoadingMessageTimer()
            } else {
                stopLoadingMessageTimer()
            }
        }
        .onChange(of: viewModel.winner) { _, newWinner in
            guard newWinner != nil, !hasScheduledNavigation else { return }
            hasScheduledNavigation = true
            let start = analysisStartTime ?? Date()
            let elapsed = Date().timeIntervalSince(start)
            let remaining = max(0, minCompareDisplayDuration - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                flowViewModel.compareFirstResult = viewModel.firstResult
                flowViewModel.compareSecondResult = viewModel.secondResult
                flowViewModel.compareWinner = viewModel.winner
                flowViewModel.navigationPath.append(.compareResults)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparing Photos")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("AI is picking the stronger photo.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
        }
    }

    private var photosSection: some View {
        HStack(spacing: 16) {
            if let image = flowViewModel.selectedImage {
                photoCard(image: image, label: "Photo A")
            }
            if let image = flowViewModel.compareImage {
                photoCard(image: image, label: "Photo B")
            }
        }
    }

    private func photoCard(image: UIImage, label: String) -> some View {
        VStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(AppColors.accent)
                .scaleEffect(1.1)
            Text(compareLoadingMessages[loadingMessageIndex])
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText.opacity(0.95))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.35), value: loadingMessageIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .id(loadingMessageIndex)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func startLoadingMessageTimer() {
        stopLoadingMessageTimer()
        loadingMessageTimer = Timer.scheduledTimer(withTimeInterval: compareLoadingMessageInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                loadingMessageIndex = (loadingMessageIndex + 1) % compareLoadingMessages.count
            }
        }
        RunLoop.main.add(loadingMessageTimer!, forMode: .common)
    }

    private func stopLoadingMessageTimer() {
        loadingMessageTimer?.invalidate()
        loadingMessageTimer = nil
    }

    private func errorSection(message: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Comparison Failed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
                Button("Try Again") {
                    viewModel.errorMessage = nil
                    guard let first = flowViewModel.selectedImageData,
                          let second = flowViewModel.compareImageData else { return }
                    Task {
                        await viewModel.analyzeBoth(firstImageData: first, secondImageData: second)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Choose Other Photos") {
                    viewModel.errorMessage = nil
                    while flowViewModel.navigationPath.count > 1 {
                        flowViewModel.navigationPath.removeLast()
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 24)
    }

    private var completeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColors.scoreHigh)
            Text("Comparison complete")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        CompareAnalyzeView(service: APIPhotoAnalysisService())
            .environmentObject(AppFlowViewModel())
    }
}
