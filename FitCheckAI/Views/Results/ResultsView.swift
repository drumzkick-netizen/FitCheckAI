//
//  ResultsView.swift
//  FitCheckAI
//

import SwiftUI

// MARK: - Layout constants
private enum ResultsLayout {
    static let sectionSpacing: CGFloat = 36
    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let breakdownCardCornerRadius: CGFloat = 16
    static let breakdownCardPadding: CGFloat = 16
    static let sectionTitleSpacing: CGFloat = 12
    static let scoreRevealDelay: Double = 0.15
    static let scoreRevealDuration: Double = 1.0
    static let sectionStagger: Double = 0.1
    static let heroRingSize: CGFloat = 152
    static let heroRingLineWidth: CGFloat = 14
    static let feedbackItemSpacing: CGFloat = 18
    static let feedbackIconSize: CGFloat = 20
}

/// Used only to present the share sheet when user taps Share.
private struct ShareableImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ResultsView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @State private var shareableItem: ShareableImageItem?
    @State private var shareErrorMessage: String?
    @State private var isShowingShareAlert = false
    @State private var isPreparingShare = false

    @State private var improveSuggestions: [String]?
    @State private var isLoadingImprove = false
    @State private var improveErrorMessage: String?

    @State private var animatedScore: Double = 0
    @State private var revealContent: Bool = false
    @State private var showScoreGlow: Bool = false
    @State private var hasAnimated: Bool = false
    @State private var imageRevealed: Bool = false
    @State private var isNewPersonalBest: Bool = false

    #if DEBUG
    @AppStorage("fitcheck_debug_results_enabled") private var debugResultsEnabled: Bool = false
    #endif

    private var result: AnalysisResult? {
        flowViewModel.latestResult
    }

    private var canShare: Bool {
        flowViewModel.selectedImage != nil &&
        flowViewModel.selectedPurpose != nil &&
        flowViewModel.latestResult != nil
    }

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 9...10: return AppColors.scoreHigh
        case 7..<9: return AppColors.scoreMid
        case 5..<7: return AppColors.scoreLow
        default: return AppColors.scorePoor
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResultsLayout.sectionSpacing) {
                if let result = result {
                    scoreHeroSection(result)
                    tierLabelSection(result)
                    newPersonalBestSection(result)
                    shareScoreCardButtonSection(result)
                    if let image = flowViewModel.selectedImage {
                        heroImageCard(image)
                    }
                    if let purpose = flowViewModel.selectedPurpose {
                        purposePill(purpose)
                    }
                    feedbackSectionCard(
                        title: "What Works",
                        icon: "checkmark.circle.fill",
                        items: result.strengths,
                        color: AppColors.scoreHigh,
                        stagger: ResultsLayout.sectionStagger * 1.5
                    )
                    feedbackSectionCard(
                        title: "Could Improve",
                        icon: "arrow.up.circle.fill",
                        items: result.improvements,
                        color: AppColors.scoreMid,
                        stagger: ResultsLayout.sectionStagger * 2
                    )
                    feedbackSectionCard(
                        title: "Suggestions",
                        icon: "lightbulb.fill",
                        items: suggestionsForDisplay(result),
                        color: AppColors.scoreLow,
                        stagger: ResultsLayout.sectionStagger * 2.5
                    )
                    breakdownSection(result)
                    tipsForBetterAnalysisSection
                    howToImproveSection
                    #if DEBUG
                    if debugResultsEnabled {
                        debugSection(result)
                    }
                    #endif
                } else {
                    if let image = flowViewModel.selectedImage {
                        heroImageCard(image)
                    }
                    if flowViewModel.selectedPurpose != nil {
                        purposePill(flowViewModel.selectedPurpose!)
                    }
                    emptyStateView
                }
                actionsSection
            }
            .appScreenContent()
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
        .background(AmbientGlowBackground())
        .navigationTitle("Results")
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                imageRevealed = true
            }
            guard !hasAnimated, let result = result else { return }
            hasAnimated = true
            animatedScore = 0
            revealContent = false
            showScoreGlow = false

            DispatchQueue.main.asyncAfter(deadline: .now() + ResultsLayout.scoreRevealDelay) {
                withAnimation(.easeOut(duration: ResultsLayout.scoreRevealDuration)) {
                    animatedScore = result.score
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showScoreGlow = true
                    revealContent = true
                    isNewPersonalBest = PersonalBestService.shared.updateIfBetter(score: result.score)
                }
            }
        }
        .sheet(item: $shareableItem) { item in
            ShareSheet(activityItems: [item.image])
        }
        .alert("Unable to Share", isPresented: $isShowingShareAlert) {
            Button("OK", role: .cancel) {
                isShowingShareAlert = false
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "Something went wrong. Try again later.")
        }
        .alert("Improve My Fit", isPresented: Binding(get: { improveErrorMessage != nil }, set: { if !$0 { improveErrorMessage = nil } })) {
            Button("OK") {
                improveErrorMessage = nil
            }
        } message: {
            Text(improveErrorMessage ?? "Something went wrong. Try again.")
        }
    }

    // MARK: - Internal debug

    #if DEBUG
    private func debugSection(_ result: AnalysisResult) -> some View {
        let debug = result.debugInfo
        let strengthsCount = debug?.strengthsCount ?? result.strengths.count
        let improvementsCount = debug?.improvementsCount ?? result.improvements.count
        let suggestionsCount = debug?.suggestionsCount ?? result.suggestions.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("INTERNAL DEBUG — Analysis")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Score: \(String(format: "%.1f", result.score))")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText)
                if let subs = result.subscores {
                    Text("Subscores — C:\(String(format: "%.1f", subs.composition))  L:\(String(format: "%.1f", subs.lighting))  P:\(String(format: "%.1f", subs.presentation))  Fit:\(String(format: "%.1f", subs.purposeFit))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.mutedText)
                }
                Text("Items — strengths: \(strengthsCount), improvements: \(improvementsCount), suggestions: \(suggestionsCount)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText)
            }

            if let debug {
                Divider()
                    .background(Color.white.opacity(0.12))
                VStack(alignment: .leading, spacing: 4) {
                    if let evaluability = debug.evaluability {
                        Text("Evaluability: \(evaluability)")
                            .font(.caption2)
                            .foregroundStyle(AppColors.mutedText)
                    }
                    Text("Visible-facts fallback: \(debug.visibleFactsFromFallback ? "yes" : "no")")
                        .font(.caption2)
                        .foregroundStyle(AppColors.mutedText)
                    if let facts = debug.visibleFactsSummary, !facts.isEmpty {
                        Text("Visible facts summary:")
                            .font(.caption2)
                            .foregroundStyle(AppColors.mutedText)
                        ForEach(facts.keys.sorted(), id: \.self) { key in
                            let value: String? = facts[key] ?? nil
                            let rendered = value ?? ""
                            Text("- \(key): \(rendered.isEmpty ? "—" : rendered)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.mutedText.opacity(0.9))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    #endif

    // MARK: - Hero image
    private func heroImageCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxHeight: 240)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: ResultsLayout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ResultsLayout.cardCornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
            .opacity(imageRevealed ? 1 : 0.85)
            .animation(.easeOut(duration: 0.4), value: imageRevealed)
    }

    private func purposePill(_ purpose: PhotoPurpose) -> some View {
        Text(purpose.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.mutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }

    // MARK: - Score hero (ring → verdict → percentile → rank)
    private func scoreHeroSection(_ result: AnalysisResult) -> some View {
        let color = scoreColor(for: result.score)
        let insight = ScoreInsights.insight(for: result.score)
        let verdictText = ScoreInsights.verdictLine(for: result)

        return VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.18),
                                color.opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: ResultsLayout.heroRingSize * 0.65
                        )
                    )
                    .frame(width: ResultsLayout.heroRingSize * 1.8, height: ResultsLayout.heroRingSize * 1.8)
                    .blur(radius: 36)

                ScoreRingView(
                    score: animatedScore,
                    size: ResultsLayout.heroRingSize,
                    lineWidth: ResultsLayout.heroRingLineWidth,
                    animateOnAppear: false
                )
                .shadow(color: showScoreGlow ? color.opacity(0.45) : .clear, radius: 20)
                .animation(.easeOut(duration: 0.4), value: showScoreGlow)
                .modifier(ConditionalGlowPulse(active: showScoreGlow))
            }
            .frame(height: ResultsLayout.heroRingSize + 40)

            VStack(spacing: 10) {
                Text(verdictText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(revealContent ? 1 : 0)
                    .offset(y: revealContent ? 0 : 8)
                    .animation(.easeOut(duration: 0.35), value: revealContent)

                if let explanationLine = ScoreInsights.scoreExplanationLine(for: result) {
                    Text(explanationLine)
                        .font(.subheadline)
                        .fontWeight(.regular)
                        .foregroundStyle(AppColors.mutedText.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(revealContent ? 1 : 0)
                        .offset(y: revealContent ? 0 : 6)
                        .animation(.easeOut(duration: 0.3).delay(0.04), value: revealContent)
                }

                Text(insight.percentileText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.mutedText.opacity(0.95))
                    .opacity(revealContent ? 1 : 0)
                    .offset(y: revealContent ? 0 : 6)
                    .animation(.easeOut(duration: 0.3).delay(0.06), value: revealContent)

                Text(insight.rankLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.2))
                    .clipShape(Capsule())
                    .opacity(revealContent ? 1 : 0)
                    .offset(y: revealContent ? 0 : 6)
                    .animation(.easeOut(duration: 0.35).delay(0.1), value: revealContent)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28, cornerRadius: ResultsLayout.cardCornerRadius)
    }

    // MARK: - Tier label (Elite Fit, Strong Fit, etc.)
    private func tierLabelSection(_ result: AnalysisResult) -> some View {
        let tier = FitScoreShareTier.label(for: result.score)
        return Text(tier)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(scoreColor(for: result.score))
            .frame(maxWidth: .infinity)
            .opacity(revealContent ? 1 : 0)
            .offset(y: revealContent ? 0 : 6)
            .animation(.easeOut(duration: 0.3).delay(0.05), value: revealContent)
    }

    // MARK: - New Personal Best (when score beats saved best)
    private func newPersonalBestSection(_ result: AnalysisResult) -> some View {
        Group {
            if isNewPersonalBest && revealContent {
                HStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.scoreHigh)
                    Text("New Personal Best")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.scoreHigh)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(AppColors.scoreHigh.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.scoreHigh.opacity(0.4), lineWidth: 1)
                )
                .opacity(revealContent ? 1 : 0)
                .offset(y: revealContent ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.08), value: revealContent)
            }
        }
    }

    // MARK: - Share Score Card (only if score >= 8) — Prominent share CTA with tier messaging
    private func shareScoreCardButtonSection(_ result: AnalysisResult) -> some View {
        Group {
            if result.score >= 8.0 {
                VStack(spacing: 16) {
                    Text(peakShareHeadline(for: result.score))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor(for: result.score))
                        .multilineTextAlignment(.center)
                    Button {
                        AnalyticsService.log(.shareScoreCard)
                        shareScoreCard()
                    } label: {
                        Label("Share Score Card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(BorderedProminentPressableStyle(tint: AppColors.accent))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(!canShare || isPreparingShare)
                    .opacity(canShare && !isPreparingShare ? 1 : 0.7)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .glassCard(padding: 20, cornerRadius: ResultsLayout.cardCornerRadius)
                .opacity(revealContent ? 1 : 0)
                .offset(y: revealContent ? 0 : 10)
                .animation(.easeOut(duration: 0.35).delay(ResultsLayout.sectionStagger * 0.8), value: revealContent)
            }
        }
    }

    private func peakShareHeadline(for score: Double) -> String {
        if score >= 9.0 { return "🏆 Top Tier Fit" }
        if score >= 8.5 { return "🔥 Elite Fit" }
        return "Share Your Score"
    }

    /// Suggestions for display: show AI suggestions when non-empty; otherwise show nothing.
    private func suggestionsForDisplay(_ result: AnalysisResult) -> [String] {
        let list = result.suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return list
    }

    // MARK: - Tips for next time — only show when backend provided real tips (not placeholder/fallback)
    private var tipsForBetterAnalysisSection: some View {
        Group {
            if let result = result, hasRealAnalysisTips(result) {
                tipsCardView(displayTips: displayTipsForAnalysis(result))
            }
        }
    }

    /// True when analysisTips from backend (after filtering generic phrase) is non-empty. Hide section when we'd only show fallback.
    private func hasRealAnalysisTips(_ result: AnalysisResult) -> Bool {
        let genericPhrase = "use good lighting and avoid cluttered backgrounds"
        let raw = result.analysisTips ?? []
        let filtered = raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().contains(genericPhrase) }
        return !filtered.isEmpty
    }

    /// Filter generic "Use good lighting and avoid cluttered backgrounds" message.
    /// When empty, return an empty list so we avoid injecting generic camera-only tips.
    private func displayTipsForAnalysis(_ result: AnalysisResult) -> [String] {
        let genericPhrase = "use good lighting and avoid cluttered backgrounds"
        let raw = result.analysisTips ?? []
        let filtered = raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().contains(genericPhrase) }
        return filtered
    }

    private func tipsCardView(displayTips: [String]) -> some View {
        VStack(alignment: .leading, spacing: ResultsLayout.sectionTitleSpacing) {
            Text("Tips for Better Analysis")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(displayTips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedText)
                    }
                }
            }
            .glassCard(padding: ResultsLayout.cardPadding, cornerRadius: ResultsLayout.cardCornerRadius)
        }
        .opacity(revealContent ? 1 : 0)
        .offset(y: revealContent ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(ResultsLayout.sectionStagger * 1.2), value: revealContent)
    }

    // MARK: - Breakdown (2x2 cards)
    private func breakdownSection(_ result: AnalysisResult) -> some View {
        Group {
            if let subscores = result.subscores {
                VStack(alignment: .leading, spacing: ResultsLayout.sectionTitleSpacing) {
                    Text("Score Breakdown")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        BreakdownScoreCard(label: "Composition", score: subscores.composition, scoreColor: scoreColor(for: subscores.composition))
                        BreakdownScoreCard(label: "Lighting", score: subscores.lighting, scoreColor: scoreColor(for: subscores.lighting))
                        BreakdownScoreCard(label: "Presentation", score: subscores.presentation, scoreColor: scoreColor(for: subscores.presentation))
                        BreakdownScoreCard(label: "Purpose Fit", score: subscores.purposeFit, scoreColor: scoreColor(for: subscores.purposeFit))
                    }
                }
                .opacity(revealContent ? 1 : 0)
                .offset(y: revealContent ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(ResultsLayout.sectionStagger), value: revealContent)
            }
        }
    }

    private func feedbackSectionCard(title: String, icon: String, items: [String], color: Color, stagger: Double) -> some View {
        VStack(alignment: .leading, spacing: ResultsLayout.sectionTitleSpacing) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: ResultsLayout.feedbackItemSpacing) {
                ForEach(items, id: \.self) { item in
                    FeedbackItemRow(icon: icon, text: item, color: color)
                }
            }
            .glassCard(padding: ResultsLayout.cardPadding, cornerRadius: ResultsLayout.cardCornerRadius)
        }
        .opacity(revealContent ? 1 : 0)
        .offset(y: revealContent ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(stagger), value: revealContent)
    }

    // MARK: - How to Improve (from Improve My Fit request)
    private var howToImproveSection: some View {
        Group {
            if let suggestions = improveSuggestions, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: ResultsLayout.sectionTitleSpacing) {
                    Text("How to Improve")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: ResultsLayout.feedbackItemSpacing) {
                        ForEach(suggestions, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.scoreMid)
                                Text(item)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .glassCard(padding: ResultsLayout.cardPadding, cornerRadius: ResultsLayout.cardCornerRadius)
                }
            }
        }
    }

    // MARK: - Shared
    private var emptyStateView: some View {
        Text("Your results will appear here.")
            .font(.subheadline)
            .foregroundStyle(AppColors.mutedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    // MARK: - Actions (grouped, clear hierarchy)
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.mutedText)
            if isPreparingShare {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Preparing share card...")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            if isLoadingImprove {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Getting improvement suggestions...")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            VStack(spacing: 12) {
                Button {
                    AnalyticsService.log(.shareScoreCard)
                    shareScoreCard()
                } label: {
                    Label("Share Score Card", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(BorderedProminentPressableStyle(tint: AppColors.accent))
                .disabled(!canShare || isPreparingShare)
                .opacity(canShare && !isPreparingShare ? 1 : 0.6)

                Button {
                    AnalyticsService.log(.improveMyFitTapped)
                    requestImproveFit()
                } label: {
                    Label("Improve My Fit", systemImage: "arrow.up.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(BorderedPressableStyle(tint: AppColors.accent))
                .disabled(flowViewModel.selectedImageData == nil || isLoadingImprove)
                .opacity(flowViewModel.selectedImageData != nil && !isLoadingImprove ? 1 : 0.6)

                Button {
                    AnalyticsService.log(.beatYourScoreStarted)
                    flowViewModel.clearBeatScoreState()
                    flowViewModel.navigationPath.append(.beatYourScore)
                } label: {
                    Label("Beat Your Score", systemImage: "arrow.trianglehead.2.forward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(BorderedPressableStyle(tint: AppColors.accent))
                .disabled(!canShare)
                .opacity(canShare ? 1 : 0.6)

                Button("Start Over") {
                    flowViewModel.resetFlow()
                    flowViewModel.requestedTabIndex = 0
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private func requestImproveFit() {
        guard let imageData = flowViewModel.selectedImageData else { return }
        improveErrorMessage = nil
        improveSuggestions = nil
        isLoadingImprove = true
        let service = APIPhotoAnalysisService()
        Task {
            defer { Task { @MainActor in isLoadingImprove = false } }
            do {
                let outcome = try await service.analyzePhoto(imageData: imageData, purpose: .improveFit)
                await MainActor.run {
                    switch outcome {
                    case .valid(let analysisResult):
                        // Use outfit improvement suggestions only: improvementSuggestions first, then improvements, then suggestions. Never analysisTips (those are for photo/camera advice).
                        let list: [String]
                        if let imp = analysisResult.improvementSuggestions, !imp.isEmpty {
                            list = imp
                        } else if !analysisResult.improvements.isEmpty {
                            list = analysisResult.improvements
                        } else {
                            list = analysisResult.suggestions
                        }
                        improveSuggestions = list.isEmpty ? nil : list
                    case .invalid(let message):
                        // Avoid showing the generic "suitable for analysis" message for Improve My Fit; the photo was already analyzed.
                        let displayMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains("doesn't appear suitable for analysis")
                            ? "Couldn't get improvement suggestions. Please try again."
                            : message
                        improveErrorMessage = displayMessage
                    }
                }
            } catch {
                await MainActor.run {
                    improveErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Share
    private func shareScoreCard() {
        guard let image = flowViewModel.selectedImage,
              let result = result else { return }

        shareableItem = nil
        shareErrorMessage = nil
        isShowingShareAlert = false
        isPreparingShare = true

        let rendered = ShareCardRenderer.renderShareCard(image: image, result: result)

        isPreparingShare = false

        if let img = rendered, img.size.width > 0, img.size.height > 0 {
            shareableItem = ShareableImageItem(image: img)
        } else {
            shareErrorMessage = "The score card could not be generated."
            isShowingShareAlert = true
        }
    }
}

// MARK: - Reusable subviews
private struct BreakdownScoreCard: View {
    let label: String
    let score: Double
    let scoreColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
            Text(ScoreFormat.display(score))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(scoreColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: ResultsLayout.breakdownCardPadding, cornerRadius: ResultsLayout.breakdownCardCornerRadius)
    }
}

private struct FeedbackItemRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: ResultsLayout.feedbackIconSize))
                .foregroundStyle(color)
                .frame(width: 28, height: 28, alignment: .top)
            Text(text)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        ResultsView()
            .environmentObject(AppFlowViewModel())
    }
}
