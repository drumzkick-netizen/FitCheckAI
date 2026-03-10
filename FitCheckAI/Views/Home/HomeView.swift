//
//  HomeView.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

// MARK: - Layout constants
private enum HomeLayout {
    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let spacingAboveRecentResults: CGFloat = 44
    static let headerSpacing: CGFloat = 8
    static let recentRowThumbnailSize: CGFloat = 52
    static let recentRowCornerRadius: CGFloat = 14
    /// Space between header and hero card.
    static let spacingAfterHeader: CGFloat = 12
    // Hero (Analyze Your Fit) – tightened spacing (~20–25% reduction)
    static let heroCardPadding: CGFloat = 17
    static let heroIconSize: CGFloat = 48
    static let heroIconCornerRadius: CGFloat = 14
    static let heroButtonCornerRadius: CGFloat = 12
    static let heroVerticalSpacing: CGFloat = 11
    static let heroButtonVerticalPadding: CGFloat = 9
    static let heroButtonSpacing: CGFloat = 12
    // Photo Battle – compact action row
    static let photoBattleRowPadding: CGFloat = 14
    static let photoBattleIconSize: CGFloat = 40
    // Daily Challenge – compact engagement hook
    static let dailyChallengePadding: CGFloat = 12
    static let dailyChallengeCornerRadius: CGFloat = 16
}

/// Purple gradient for primary hero CTA (accent → accentSecondary).
private var heroButtonGradient: LinearGradient {
    LinearGradient(
        colors: [AppColors.accent, AppColors.accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct HomeView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var presentedBattle: PhotoBattleResult?
    @State private var showPaywall: Bool = false

    /// Merged recent records (single analyses + battles) sorted by date, newest first.
    private var recentRecords: [HistoryRecord] {
        Array(historyViewModel.mergedRecords.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HomeLayout.sectionSpacing) {
                headerSection
                    .padding(.bottom, HomeLayout.spacingAfterHeader)
                heroAnalyzeFitCard
                photoBattleCard
                dailyChallengeSection
                bestScoreSection
                recentResultsSection
                    .padding(.top, HomeLayout.spacingAboveRecentResults)
            }
            // Root content column: this is the true horizontal inset for the Home screen.
            .appScreenContent()
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $presentedBattle) { battle in
            NavigationStack {
                BattleHistoryDetailView(battle: battle)
                    .environmentObject(historyViewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                presentedBattle = nil
                            }
                            .foregroundStyle(AppColors.accent)
                        }
                    }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FitCheck AI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero: Analyze Your Fit (camera-first, Take Photo + Upload Photo)
    private var heroAnalyzeFitCard: some View {
        VStack(spacing: HomeLayout.heroVerticalSpacing) {
            Image(systemName: "tshirt.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.accent)
                .frame(width: HomeLayout.heroIconSize, height: HomeLayout.heroIconSize)
                .background(AppColors.accent.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: HomeLayout.heroIconCornerRadius))
            VStack(spacing: 4) {
                Text("Analyze Your Fit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Snap or upload a photo to get your AI outfit score.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: HomeLayout.heroButtonSpacing) {
                Button {
                    if subscriptionManager.canAnalyze {
                        flowViewModel.clearSinglePhotoFlowState()
                        flowViewModel.selectedPurpose = nil
                        flowViewModel.preferCameraOnNextCapture = true
                        flowViewModel.navigationPath.append(.capture)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HomeLayout.heroButtonVerticalPadding)
                }
                .background(heroButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: HomeLayout.heroButtonCornerRadius))
                .shadow(color: AppColors.accent.opacity(0.1), radius: 4, y: 2)
                .buttonStyle(PressableButtonStyle())

                Button {
                    if subscriptionManager.canAnalyze {
                        flowViewModel.clearSinglePhotoFlowState()
                        flowViewModel.selectedPurpose = nil
                        flowViewModel.preferLibraryOnNextCapture = true
                        flowViewModel.navigationPath.append(.capture)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label("Upload Photo", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HomeLayout.heroButtonVerticalPadding)
                }
                .background(heroButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: HomeLayout.heroButtonCornerRadius))
                .shadow(color: AppColors.accent.opacity(0.1), radius: 4, y: 2)
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(HomeLayout.heroCardPadding)
        .frame(maxWidth: .infinity)
        .glassCard(padding: HomeLayout.heroCardPadding, cornerRadius: HomeLayout.cardCornerRadius)
        .shadow(color: AppColors.accent.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: - Photo Battle (compact action row)
    private var photoBattleCard: some View {
        TappableCard(action: {
            flowViewModel.selectedPurpose = .compare
            flowViewModel.selectedImage = nil
            flowViewModel.selectedImageData = nil
            flowViewModel.compareImage = nil
            flowViewModel.compareImageData = nil
            flowViewModel.navigationPath.append(.compareCapture)
        }) {
            HStack(spacing: 14) {
                Image(systemName: "square.on.square.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.scoreMid)
                    .frame(width: HomeLayout.photoBattleIconSize, height: HomeLayout.photoBattleIconSize)
                    .background(AppColors.scoreMid.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo Battle")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Compare two looks and see which fit wins.")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                Spacer(minLength: 8)
                Text("Start Battle")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.scoreMid)
                    .clipShape(Capsule())
            }
            .padding(HomeLayout.photoBattleRowPadding)
            .frame(maxWidth: .infinity)
            .glassCard(padding: HomeLayout.photoBattleRowPadding, cornerRadius: HomeLayout.cardCornerRadius)
        }
    }

    // MARK: - Daily Fit Challenge (compact engagement hook; does not compete with hero)
    private var dailyChallengeSection: some View {
        Button {
            if subscriptionManager.canAnalyze {
                flowViewModel.clearSinglePhotoFlowState()
                flowViewModel.selectedPurpose = nil
                flowViewModel.navigationPath.append(.capture)
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasCompletedChallengeToday ? "checkmark.circle.fill" : "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(hasCompletedChallengeToday ? AppColors.scoreHigh : AppColors.mutedText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("✨ Daily Fit Challenge")
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                    Text(DailyFitChallengeService.todayChallengePrompt)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText.opacity(0.8))
            }
            .padding(HomeLayout.dailyChallengePadding)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: HomeLayout.dailyChallengeCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: HomeLayout.dailyChallengeCornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainPressableStyle())
    }

    private var hasCompletedChallengeToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for record in historyViewModel.mergedRecords {
            let recordDay = calendar.startOfDay(for: record.date)
            if recordDay == today { return true }
        }
        return false
    }

    // MARK: - Best Score
    private var bestScoreSection: some View {
        Group {
            if let best = PersonalBestService.shared.bestScore {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.scoreHigh)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Score")
                            .font(.caption)
                            .foregroundStyle(AppColors.mutedText)
                        Text(ScoreFormat.display(best))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(FitScoreShareTier.label(for: best))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.scoreHigh.opacity(0.95))
                }
                .padding(HomeLayout.cardPadding)
                .glassCard(padding: HomeLayout.cardPadding, cornerRadius: HomeLayout.cardCornerRadius)
            }
        }
    }

    // MARK: - Recent results
    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Results")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            if recentRecords.isEmpty {
                recentResultsEmptyState
            } else {
                VStack(spacing: 14) {
                    ForEach(recentRecords, id: \.id) { record in
                        recentResultRow(record)
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
    }

    private var recentResultsEmptyState: some View {
        VStack(spacing: 8) {
            Text("No fits analyzed yet")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("Analyze your first outfit to start building your score history.")
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassCard(padding: 12, cornerRadius: HomeLayout.cardCornerRadius)
        .padding(.horizontal, 12)
    }

    private func recentResultRow(_ record: HistoryRecord) -> some View {
        Group {
            switch record {
            case .single(let item):
                Button {
                    flowViewModel.selectedImage = UIImage(data: item.imageData)
                    flowViewModel.selectedImageData = item.imageData
                    flowViewModel.selectedPurpose = item.purpose
                    flowViewModel.latestResult = item.result
                    flowViewModel.navigationPath.append(.results)
                } label: {
                    recentSingleRow(item: item)
                }
                .buttonStyle(PlainPressableStyle())
            case .battle(let battle):
                Button {
                    presentedBattle = battle
                } label: {
                    recentBattleRow(battle: battle)
                }
                .buttonStyle(PlainPressableStyle())
            case .beatYourScore(let result):
                recentBeatYourScoreRow(result: result)
            }
        }
    }

    private func recentBeatYourScoreRow(result: BeatYourScoreResult) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                if let img = UIImage(data: result.originalImageData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("→")
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                if let img = UIImage(data: result.newImageData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(result.improved ? AppColors.scoreHigh.opacity(0.7) : Color.white.opacity(0.06), lineWidth: result.improved ? 2 : 1)
                        )
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Beat Your Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(result.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.improved ? String(format: "+%.1f", result.scoreDifference) : ScoreFormat.display(result.newScore))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(result.improved ? AppColors.scoreHigh : AppColors.mutedText)
                Text(ScoreFormat.display(result.originalScore) + " → " + ScoreFormat.display(result.newScore))
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .glassCard(padding: 14, cornerRadius: HomeLayout.cardCornerRadius)
    }

    private func recentSingleRow(item: PhotoAnalysis) -> some View {
        HStack(spacing: 14) {
                if let uiImage = UIImage(data: item.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: HomeLayout.recentRowThumbnailSize, height: HomeLayout.recentRowThumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: HomeLayout.recentRowCornerRadius))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.purpose.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Text(item.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(AppColors.mutedText)
                }
                Spacer()
                Text(ScoreFormat.display(item.result.score))
                    .font(.headline)
                    .foregroundStyle(AppColors.scoreColor(for: item.result.score))
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .glassCard(padding: 14, cornerRadius: HomeLayout.cardCornerRadius)
    }

    private func recentBattleRow(battle: PhotoBattleResult) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                thumbnailBlock(data: battle.imageAData, isWinner: battle.winner == .photoA)
                Text("vs")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.mutedText)
                thumbnailBlock(data: battle.imageBData, isWinner: battle.winner == .photoB)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Photo Battle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(battle.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
            Spacer()
            Text(battleWinnerShort(battle.winner))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.scoreMid)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.mutedText.opacity(0.8))
        }
        .glassCard(padding: 14, cornerRadius: HomeLayout.cardCornerRadius)
    }

    private func thumbnailBlock(data: Data, isWinner: Bool) -> some View {
        Group {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(AppColors.cardBackground)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isWinner ? AppColors.scoreHigh.opacity(0.6) : Color.white.opacity(0.06), lineWidth: isWinner ? 2 : 1)
        )
    }

    private func battleWinnerShort(_ winner: CompareWinner) -> String {
        switch winner {
        case .photoA: return "A won"
        case .photoB: return "B won"
        case .tie: return "Tie"
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppFlowViewModel())
            .environmentObject(HistoryViewModel())
    }
}
