//
//  CompareResultsView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

// MARK: - Layout constants for comparison cards
private enum CompareLayout {
    static let cardImageHeight: CGFloat = 180
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let vsPillWidth: CGFloat = 40
    static let vsPillHeight: CGFloat = 32
    static let rowMaxWidth: CGFloat = 420
}

struct CompareResultsView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @State private var shareableItem: ShareableImageWrapper?
    @State private var shareErrorMessage: String?
    @State private var isShowingShareAlert = false
    @State private var isPreparingShare = false
    @State private var winnerRevealed = false
    @State private var hasSavedToHistory = false

    private var winner: CompareWinner? { flowViewModel.compareWinner }
    private var firstResult: AnalysisResult? { flowViewModel.compareFirstResult }
    private var secondResult: AnalysisResult? { flowViewModel.compareSecondResult }

    private var canShareComparisonCard: Bool {
        flowViewModel.selectedImage != nil
            && flowViewModel.compareImage != nil
            && firstResult != nil
            && secondResult != nil
            && winner != nil
    }

    /// Can share the poll-style "Let Friends Decide" card (only needs both photos).
    private var canSharePollCard: Bool {
        flowViewModel.selectedImage != nil && flowViewModel.compareImage != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                winnerHeaderSection
                if let first = flowViewModel.selectedImage,
                   let second = flowViewModel.compareImage,
                   let r1 = firstResult,
                   let r2 = secondResult {
                    comparisonCards(photoA: first, photoB: second, resultA: r1, resultB: r2)
                    explanationSection(resultA: r1, resultB: r2)
                }
                actionsSection
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Photo Battle Result")
        .preferredColorScheme(.dark)
        .sheet(item: $shareableItem, onDismiss: { shareableItem = nil }) { wrapper in
            ShareSheet(activityItems: [wrapper.image])
        }
        .alert("Unable to Share", isPresented: $isShowingShareAlert) {
            Button("OK") {
                isShowingShareAlert = false
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "Something went wrong. Try again later.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                winnerRevealed = true
            }
            saveBattleToHistoryIfNeeded()
            if winner != nil { AnalyticsService.log(.photoBattleCompleted) }
        }
    }

    private var winnerHeaderSection: some View {
        Group {
            if let winner = winner, let r1 = firstResult, let r2 = secondResult {
                VStack(spacing: 12) {
                    if winner == .tie {
                        Image(systemName: "equal.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.mutedText.opacity(0.8))
                        Text("Tie")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Both photos scored similarly")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                    } else {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.scoreHigh)
                        Text(winnerHeadline(winner))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        if let diffLine = scoreDifferenceLine(winner, resultA: r1, resultB: r2) {
                            Text(diffLine)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.scoreHigh.opacity(0.95))
                        }
                        if let adv = advantageLine(r1, r2) {
                            Text(adv)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.scoreHigh)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(AppColors.scoreHigh.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .opacity(winnerRevealed ? 1 : 0)
                .offset(y: winnerRevealed ? 0 : 12)
            }
        }
    }

    private func advantageLine(_ resultA: AnalysisResult, _ resultB: AnalysisResult) -> String? {
        guard let w = winner, w != .tie else { return nil }
        let diff = abs(resultA.score - resultB.score)
        return String(format: "+%.1f advantage", diff)
    }

    private func winnerHeadline(_ w: CompareWinner) -> String {
        switch w {
        case .photoA: return "Photo A Wins"
        case .photoB: return "Photo B Wins"
        case .tie: return "Tie"
        }
    }

    private func scoreDifferenceLine(_ w: CompareWinner, resultA: AnalysisResult, resultB: AnalysisResult) -> String? {
        guard w != .tie else { return nil }
        let diff = abs(resultA.score - resultB.score)
        let winnerScore = w == .photoA ? resultA.score : resultB.score
        let loserScore = w == .photoA ? resultB.score : resultA.score
        return String(format: "Wins by %.1f  ·  %.1f vs %.1f", diff, winnerScore, loserScore)
    }

    private func comparisonCards(photoA: UIImage, photoB: UIImage, resultA: AnalysisResult, resultB: AnalysisResult) -> some View {
        HStack(alignment: .top, spacing: CompareLayout.cardSpacing) {
            compareCard(
                image: photoA,
                result: resultA,
                label: "Photo A",
                isWinner: winner == .photoA
            )
            vsDivider
            compareCard(
                image: photoB,
                result: resultB,
                label: "Photo B",
                isWinner: winner == .photoB
            )
        }
        .frame(maxWidth: CompareLayout.rowMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .opacity(winnerRevealed ? 1 : 0)
        .offset(y: winnerRevealed ? 0 : 16)
        .animation(.easeOut(duration: 0.45).delay(0.1), value: winnerRevealed)
    }

    private var vsDivider: some View {
        Text("VS")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: CompareLayout.vsPillWidth, height: CompareLayout.vsPillHeight)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.top, CompareLayout.cardPadding + CompareLayout.cardImageHeight / 2 - CompareLayout.vsPillHeight / 2)
    }

    private func compareCard(image: UIImage, result: AnalysisResult, label: String, isWinner: Bool) -> some View {
        let accentColor = isWinner ? AppColors.scoreHigh : AppColors.mutedText
        let cardScale: CGFloat = isWinner ? (winnerRevealed ? 1.0 : 0.95) : 1.0
        let shadowOpacity = isWinner ? 0.32 : 0.25
        let shadowRadius: CGFloat = isWinner ? 12 : 10
        return VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: CompareLayout.cardImageHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CompareLayout.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: CompareLayout.cardCornerRadius)
                            .stroke(isWinner ? accentColor.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isWinner ? 2.5 : 1)
                    )
                    .shadow(color: isWinner ? accentColor.opacity(shadowOpacity) : Color.black.opacity(0.25), radius: shadowRadius, x: 0, y: 6)
                    .scaleEffect(cardScale)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: winnerRevealed)
                if isWinner {
                    Text("Winner")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(accentColor)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding(8)
                }
            }
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isWinner ? .white : AppColors.mutedText)
            Text(ScoreFormat.display(result.score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: CompareLayout.cardImageHeight + 80)
        .glassCard(padding: CompareLayout.cardPadding, cornerRadius: CompareLayout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CompareLayout.cardCornerRadius)
                .stroke(isWinner ? accentColor.opacity(0.35) : Color.clear, lineWidth: 2)
        )
    }

    private func explanationSection(resultA: AnalysisResult, resultB: AnalysisResult) -> some View {
        let sectionTitle = winner == .tie ? "Summary" : "Why It Won"
        let bulletItems = whyItWonBullets(resultA: resultA, resultB: resultB)
        let fallbackText = explanationText(resultA: resultA, resultB: resultB)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if winner != .tie {
                    Image(systemName: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.scoreHigh.opacity(0.9))
                }
                Text(sectionTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            if !bulletItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(bulletItems.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.scoreHigh.opacity(0.9))
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.mutedText)
                        }
                    }
                }
            } else {
                Text(fallbackText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
            }
        }
        .glassCard(padding: 14, cornerRadius: 18)
        .opacity(winnerRevealed ? 1 : 0)
        .offset(y: winnerRevealed ? 0 : 8)
        .animation(.easeOut(duration: 0.4).delay(0.2), value: winnerRevealed)
    }

    /// Bullet points from the winning photo's strengths (existing analysis feedback).
    private func whyItWonBullets(resultA: AnalysisResult, resultB: AnalysisResult) -> [String] {
        guard winner != .tie else { return [] }
        let winnerResult = winner == .photoA ? resultA : resultB
        let items = winnerResult.strengths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
        if items.isEmpty {
            return ["Stronger overall presentation and composition."]
        }
        return Array(items)
    }

    private func explanationText(resultA: AnalysisResult, resultB: AnalysisResult) -> String {
        let diff = abs(resultA.score - resultB.score)
        if diff < 0.2 {
            return "Both photos scored similarly."
        }
        if resultA.score > resultB.score {
            let strength = resultA.strengths.first ?? "stronger overall presentation"
            return "Photo A stands out with \(strength.lowercased())."
        } else {
            let strength = resultB.strengths.first ?? "stronger overall presentation"
            return "Photo B stands out with \(strength.lowercased())."
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.mutedText)
            if winner != nil {
                Button {
                    saveBattleToHistoryIfNeeded()
                } label: {
                    Label(hasSavedToHistory ? "Saved" : "Save Result", systemImage: hasSavedToHistory ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(BorderedPressableStyle(tint: AppColors.accent))
                .disabled(hasSavedToHistory)
                .opacity(hasSavedToHistory ? 0.7 : 1)
            }

            Button("Run Another Battle") {
                flowViewModel.resetFlow()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)

            Button {
                shareComparisonCardTapped()
            } label: {
                if isPreparingShare {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Preparing...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    Label("Share Battle Result", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .buttonStyle(BorderedPressableStyle(tint: AppColors.accent))
            .disabled(!canShareComparisonCard || isPreparingShare)
            .opacity(canShareComparisonCard && !isPreparingShare ? 1 : 0.5)

            Button {
                letFriendsDecideTapped()
            } label: {
                Label("Let Friends Decide", systemImage: "person.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.accent)
            .disabled(!canSharePollCard || isPreparingShare)
            .opacity(canSharePollCard && !isPreparingShare ? 1 : 0.5)

            if winner != .tie && winner != nil {
                Button {
                    shareWinnerTapped()
                } label: {
                    Label("Share Winner Photo", systemImage: "photo")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainPressableStyle())
                .disabled(!canShareComparisonCard || isPreparingShare)
                .opacity(canShareComparisonCard && !isPreparingShare ? 0.9 : 0.5)
            }
        }
        .padding(.top, 16)
    }

    private func shareComparisonCardTapped() {
        AnalyticsService.log(.shareBattleCard)
        guard let first = flowViewModel.selectedImage,
              let second = flowViewModel.compareImage,
              let r1 = firstResult,
              let r2 = secondResult,
              let w = winner else { return }

        shareableItem = nil
        shareErrorMessage = nil
        isShowingShareAlert = false
        isPreparingShare = true

        let rendered = PhotoBattleShareCardView.renderPhotoBattleShareCard(
            imageA: first,
            imageB: second,
            scoreA: r1.score,
            scoreB: r2.score,
            winner: w
        )

        isPreparingShare = false

        if let img = rendered, img.size.width > 0, img.size.height > 0 {
            shareableItem = ShareableImageWrapper(image: img)
        } else {
            shareErrorMessage = "The comparison card could not be generated."
            isShowingShareAlert = true
        }
    }

    private func letFriendsDecideTapped() {
        guard let first = flowViewModel.selectedImage,
              let second = flowViewModel.compareImage else { return }

        shareableItem = nil
        shareErrorMessage = nil
        isShowingShareAlert = false
        isPreparingShare = true

        let rendered = PhotoBattlePollShareCardView.renderPollShareCard(imageA: first, imageB: second)

        isPreparingShare = false

        if let img = rendered, img.size.width > 0, img.size.height > 0 {
            shareableItem = ShareableImageWrapper(image: img)
        } else {
            shareErrorMessage = "The share card could not be generated."
            isShowingShareAlert = true
        }
    }

    private func shareWinnerTapped() {
        guard let w = winner, w != .tie,
              let img = w == .photoA ? flowViewModel.selectedImage : flowViewModel.compareImage else {
            return
        }
        shareableItem = ShareableImageWrapper(image: img)
    }

    private func saveBattleToHistoryIfNeeded() {
        guard !hasSavedToHistory,
              let w = winner,
              let dataA = flowViewModel.selectedImageData,
              let dataB = flowViewModel.compareImageData,
              let r1 = firstResult,
              let r2 = secondResult else { return }
        hasSavedToHistory = true
        historyViewModel.addBattle(
            imageAData: dataA,
            imageBData: dataB,
            scoreA: r1.score,
            scoreB: r2.score,
            winner: w
        )
    }

}

// MARK: - Share sheet support
private struct ShareableImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    NavigationStack {
        CompareResultsView()
            .environmentObject(AppFlowViewModel())
            .environmentObject(HistoryViewModel())
    }
}
