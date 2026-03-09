//
//  BeatYourScoreView.swift
//  FitCheckAI
//

import PhotosUI
import SwiftUI
import UIKit

private let beatScoreCardImageHeight: CGFloat = 180
private let beatScoreCardCornerRadius: CGFloat = 18
private let beatScoreCardPadding: CGFloat = 16
private let beatScoreCardSpacing: CGFloat = 12
private let beatScoreRowMaxWidth: CGFloat = 420
private let jpegCompressionQuality: CGFloat = 0.85

struct BeatYourScoreView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var comparisonRevealed = false
    @State private var hasSavedToHistory = false

    private var originalImage: UIImage? { flowViewModel.selectedImage }
    private var originalResult: AnalysisResult? { flowViewModel.latestResult }
    private var purpose: PhotoPurpose? { flowViewModel.selectedPurpose }
    private var secondImage: UIImage? { flowViewModel.beatScoreSecondImage }
    private var secondResult: AnalysisResult? { flowViewModel.beatScoreSecondResult }

    private var hasSecondPhoto: Bool { flowViewModel.beatScoreSecondImage != nil }
    private var hasSecondResult: Bool { flowViewModel.beatScoreSecondResult != nil }
    private var showComparison: Bool { hasSecondResult && originalResult != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showComparison, let origImg = originalImage, let secImg = secondImage, let r1 = originalResult, let r2 = secondResult {
                    comparisonHeader(r1: r1, r2: r2)
                    comparisonCards(originalImage: origImg, newImage: secImg, originalResult: r1, newResult: r2)
                } else if isAnalyzing {
                    analysisLoadingSection
                } else if hasSecondPhoto && !hasSecondResult && errorMessage == nil {
                    analysisLoadingSection
                } else {
                    originalSection
                    if originalResult != nil {
                        secondPhotoSection
                    }
                }
                if let msg = errorMessage {
                    errorBanner(message: msg)
                }
                Spacer(minLength: 32)
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Beat Your Score")
        .preferredColorScheme(.dark)
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadSecondPhoto(from: newItem) }
        }
        .onChange(of: flowViewModel.beatScoreSecondImageData) { _, newData in
            if newData != nil && flowViewModel.beatScoreSecondResult == nil && !isAnalyzing {
                runAnalysis()
            }
        }
        .onChange(of: showComparison) { _, showing in
            if showing { saveToHistoryIfNeeded() }
        }
        .onAppear {
            if showComparison { saveToHistoryIfNeeded() }
        }
    }

    private func saveToHistoryIfNeeded() {
        guard !hasSavedToHistory,
              let origData = flowViewModel.selectedImageData,
              let newData = flowViewModel.beatScoreSecondImageData,
              let r1 = originalResult,
              let r2 = secondResult else { return }
        hasSavedToHistory = true
        historyViewModel.addBeatYourScore(
            originalImageData: origData,
            newImageData: newData,
            originalScore: r1.score,
            newScore: r2.score
        )
    }

    // MARK: - Comparison header (verdict + score difference)
    private func comparisonHeader(r1: AnalysisResult, r2: AnalysisResult) -> some View {
        let improved = r2.score > r1.score
        let diff = r2.score - r1.score
        let headline = improved ? "You Improved Your Fit" : (diff == 0 ? "It's a Tie" : "Original Fit Wins")
        let diffLine: String = if diff > 0 { String(format: "+%.1f Improvement", diff) }
            else if diff < 0 { String(format: "%.1f Lower Score", diff) }
            else { "No change" }

        return VStack(spacing: 12) {
            Image(systemName: improved ? "arrow.up.circle.fill" : "shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(improved ? AppColors.scoreHigh : AppColors.mutedText.opacity(0.9))
            Text(headline)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(diffLine)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(improved ? AppColors.scoreHigh : AppColors.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .opacity(comparisonRevealed ? 1 : 0)
        .offset(y: comparisonRevealed ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                comparisonRevealed = true
            }
        }
    }

    // MARK: - Side-by-side cards (Original Fit | New Fit, highlight higher)
    private func comparisonCards(originalImage: UIImage, newImage: UIImage, originalResult: AnalysisResult, newResult: AnalysisResult) -> some View {
        let originalWins = originalResult.score >= newResult.score
        let newWins = newResult.score > originalResult.score

        return HStack(alignment: .top, spacing: beatScoreCardSpacing) {
            scoreCard(
                image: originalImage,
                label: "Original Fit",
                score: originalResult.score,
                isHighlighted: originalWins
            )
            vsDivider
            scoreCard(
                image: newImage,
                label: "New Fit",
                score: newResult.score,
                isHighlighted: newWins
            )
        }
        .frame(maxWidth: beatScoreRowMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .opacity(comparisonRevealed ? 1 : 0)
        .offset(y: comparisonRevealed ? 0 : 16)
        .animation(.easeOut(duration: 0.45).delay(0.1), value: comparisonRevealed)
    }

    private var vsDivider: some View {
        Text("VS")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 40, height: 32)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.top, beatScoreCardPadding + beatScoreCardImageHeight / 2 - 16)
    }

    private func scoreCard(image: UIImage, label: String, score: Double, isHighlighted: Bool) -> some View {
        let accentColor = isHighlighted ? AppColors.scoreHigh : AppColors.mutedText
        let shadowOpacity: Double = isHighlighted ? 0.32 : 0.25
        let shadowRadius: CGFloat = isHighlighted ? 12 : 10
        return VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: beatScoreCardImageHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: beatScoreCardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: beatScoreCardCornerRadius)
                            .stroke(isHighlighted ? accentColor.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isHighlighted ? 2.5 : 1)
                    )
                    .shadow(color: isHighlighted ? accentColor.opacity(shadowOpacity) : Color.black.opacity(0.25), radius: shadowRadius, x: 0, y: 6)
                if isHighlighted {
                    Text("Best")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(accentColor)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .padding(8)
                }
            }
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isHighlighted ? .white : AppColors.mutedText)
            Text(ScoreFormat.display(score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: beatScoreCardImageHeight + 80)
        .padding(beatScoreCardPadding)
        .background(
            RoundedRectangle(cornerRadius: beatScoreCardCornerRadius)
                .fill(isHighlighted ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        )
        .clipShape(RoundedRectangle(cornerRadius: beatScoreCardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: beatScoreCardCornerRadius)
                .stroke(isHighlighted ? accentColor.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Original photo + score
    private var originalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your original result")
                .font(.headline)
                .foregroundStyle(.white)
            if let img = originalImage, let res = originalResult {
                GlowCard(padding: beatScoreCardPadding, cornerRadius: beatScoreCardCornerRadius) {
                    VStack(spacing: 12) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: beatScoreCardImageHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: beatScoreCardCornerRadius))
                        HStack {
                            Text("Original Fit")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.mutedText)
                            Spacer()
                            Text(ScoreFormat.display(res.score))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Choose second photo
    private var secondPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try a second outfit to beat your score")
                .font(.headline)
                .foregroundStyle(.white)
            if let second = secondImage {
                GlowCard(padding: beatScoreCardPadding, cornerRadius: beatScoreCardCornerRadius) {
                    VStack(spacing: 12) {
                        Image(uiImage: second)
                            .resizable()
                            .scaledToFill()
                            .frame(height: beatScoreCardImageHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: beatScoreCardCornerRadius))
                        Text("New photo selected")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                    }
                }
                if isAnalyzing {
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    GlowCard(padding: 16, cornerRadius: beatScoreCardCornerRadius) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                            Text("Choose from Library")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppColors.mutedText)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .buttonStyle(CardTapButtonStyle())
            }
        }
    }

    private var analysisLoadingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analyzing your new photo...")
                .font(.headline)
                .foregroundStyle(.white)
            GlowCard(padding: 20, cornerRadius: 20) {
                AnalysisProgressView(isComplete: .constant(false))
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Load second photo and run analysis
    private func loadSecondPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            flowViewModel.beatScoreSecondImage = nil
            flowViewModel.beatScoreSecondImageData = nil
            flowViewModel.beatScoreSecondResult = nil
            errorMessage = nil
            return
        }
        errorMessage = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            flowViewModel.beatScoreSecondImage = nil
            flowViewModel.beatScoreSecondImageData = nil
            errorMessage = "Could not load the selected photo."
            return
        }
        await MainActor.run {
            // Downsample and compress second photo before storing to limit memory usage.
            let preparedData = ImageUploadPreparer.prepareForAnalysis(imageData: data)
            flowViewModel.beatScoreSecondImageData = preparedData
            flowViewModel.beatScoreSecondImage = UIImage(data: preparedData)
        }
    }

    private func runAnalysis() {
        guard let imageData = flowViewModel.beatScoreSecondImageData,
              let purpose = purpose else { return }
        errorMessage = nil
        isAnalyzing = true
        let service = APIPhotoAnalysisService()
        Task {
            defer { Task { @MainActor in isAnalyzing = false } }
            do {
                let outcome = try await service.analyzePhoto(imageData: imageData, purpose: purpose)
                await MainActor.run {
                    switch outcome {
                    case .valid(let result):
                        flowViewModel.beatScoreSecondResult = result
                    case .invalid(let message):
                        errorMessage = message
                        flowViewModel.beatScoreSecondResult = nil
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? AnalysisServiceError)?.errorDescription ?? "Analysis failed. Please try again."
                    flowViewModel.beatScoreSecondResult = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BeatYourScoreView()
            .environmentObject(AppFlowViewModel())
            .environmentObject(HistoryViewModel())
    }
}
