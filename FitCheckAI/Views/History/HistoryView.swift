//
//  HistoryView.swift
//  FitCheckAI
//

import SwiftUI

private enum HistorySection: String, CaseIterable {
    case analyses = "Single photo"
    case battles = "Photo Battles"
    case beatYourScore = "Beat Your Score"
}

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case fits = "Fits"
    case battles = "Battles"
    case improvements = "Improvements"
}

struct HistoryView: View {
    @EnvironmentObject private var historyViewModel: HistoryViewModel
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @State private var selectedFilter: HistoryFilter = .all

    private var hasAnalyses: Bool { !historyViewModel.items.isEmpty }
    private var hasBattles: Bool { !historyViewModel.battleItems.isEmpty }
    private var hasBeatYourScore: Bool { !historyViewModel.beatYourScoreItems.isEmpty }
    private var isEmpty: Bool { !hasAnalyses && !hasBattles && !hasBeatYourScore }

    private var filteredAnalyses: [PhotoAnalysis] {
        guard selectedFilter == .all || selectedFilter == .fits else { return [] }
        return historyViewModel.items
    }
    private var filteredBattles: [PhotoBattleResult] {
        guard selectedFilter == .all || selectedFilter == .battles else { return [] }
        return historyViewModel.battleItems
    }
    private var filteredBeatYourScore: [BeatYourScoreResult] {
        guard selectedFilter == .all || selectedFilter == .improvements else { return [] }
        return historyViewModel.beatYourScoreItems
    }
    private var hasFilteredContent: Bool {
        !filteredAnalyses.isEmpty || !filteredBattles.isEmpty || !filteredBeatYourScore.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    filterSection
                    historyList
                }
            }
        }
        .background(AmbientGlowBackground())
        .navigationTitle("History")
        .preferredColorScheme(.dark)
        .toolbar {
            if !isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Start Over") {
                            startOver()
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppColors.mutedText)
                        clearAllButton
                    }
                }
            }
        }
        .navigationDestination(for: PhotoAnalysis.self) { item in
            HistoryDetailView(item: item)
                .environmentObject(historyViewModel)
        }
        .navigationDestination(for: PhotoBattleResult.self) { battle in
            BattleHistoryDetailView(battle: battle)
                .environmentObject(historyViewModel)
        }
        .navigationDestination(for: BeatYourScoreResult.self) { result in
            BeatYourScoreDetailView(result: result)
                .environmentObject(historyViewModel)
        }
    }

    private var filterSection: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.mutedText.opacity(0.5))
                Text("No results yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Run your first fit check or start a Photo Battle.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                HStack(spacing: 12) {
                    Button {
                        flowViewModel.clearSinglePhotoFlowState()
                        flowViewModel.selectedPurpose = nil
                        flowViewModel.navigationPath = [.capture]
                        flowViewModel.requestedTabIndex = 0
                    } label: {
                        Label("Analyze a Fit", systemImage: "tshirt.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BorderedProminentPressableStyle(tint: AppColors.accent))
                    Button {
                        flowViewModel.selectedPurpose = .compare
                        flowViewModel.selectedImage = nil
                        flowViewModel.selectedImageData = nil
                        flowViewModel.compareImage = nil
                        flowViewModel.compareImageData = nil
                        flowViewModel.navigationPath = [.compareCapture]
                        flowViewModel.requestedTabIndex = 0
                    } label: {
                        Label("Start Photo Battle", systemImage: "square.on.square.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BorderedPressableStyle(tint: AppColors.accent))
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
            }
            .padding(28)
            .glassCard(padding: 28, cornerRadius: 24)
            .padding(.horizontal, AppLayout.horizontalPadding)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var historyList: some View {
        List {
            if !filteredAnalyses.isEmpty {
                Section {
                    ForEach(filteredAnalyses) { item in
                        NavigationLink(value: item) {
                            HistoryItemCardView(item: item)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: AppLayout.horizontalPadding, bottom: 6, trailing: AppLayout.horizontalPadding))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: historyViewModel.deleteAnalyses)
                } header: {
                    sectionHeader(HistorySection.analyses.rawValue)
                }
                .listSectionSeparator(.visible, edges: .bottom)
            }

            if !filteredBattles.isEmpty {
                Section {
                    ForEach(filteredBattles) { battle in
                        NavigationLink(value: battle) {
                            BattleHistoryCardView(battle: battle)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: AppLayout.horizontalPadding, bottom: 6, trailing: AppLayout.horizontalPadding))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: historyViewModel.deleteBattles)
                } header: {
                    sectionHeader(HistorySection.battles.rawValue)
                }
                .listSectionSeparator(.visible, edges: .bottom)
            }

            if !filteredBeatYourScore.isEmpty {
                Section {
                    ForEach(filteredBeatYourScore) { result in
                        NavigationLink(value: result) {
                            BeatYourScoreHistoryRowView(result: result)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: AppLayout.horizontalPadding, bottom: 6, trailing: AppLayout.horizontalPadding))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: historyViewModel.deleteBeatYourScoreAt)
                } header: {
                    sectionHeader(HistorySection.beatYourScore.rawValue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.mutedText.opacity(0.95))
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 20, leading: AppLayout.horizontalPadding, bottom: 6, trailing: AppLayout.horizontalPadding))
    }

    private var clearAllButton: some View {
        Button {
            historyViewModel.clearAll()
        } label: {
            Text("Clear All")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.mutedText)
        }
    }

    private func startOver() {
        flowViewModel.resetFlow()
        flowViewModel.requestedTabIndex = 0
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(HistoryViewModel())
            .environmentObject(AppFlowViewModel())
    }
}
