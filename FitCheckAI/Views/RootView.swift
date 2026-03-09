//
//  RootView.swift
//  FitCheckAI
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var flowViewModel: AppFlowViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $flowViewModel.navigationPath) {
                HomeView()
                    .navigationDestination(for: FlowRoute.self) { route in
                        switch route {
                        case .capture:
                            CaptureView()
                        case .cameraCapture:
                            CameraCaptureView()
                        case .purpose:
                            PurposeSelectionView()
                        case .adjustPhoto:
                            PhotoAdjustmentView()
                        case .analyze:
                            AnalyzeView(service: APIPhotoAnalysisService())
                        case .results:
                            ResultsView()
                        case .compareCapture:
                            CompareCaptureView()
                        case .compareAnalyze:
                            CompareAnalyzeView(service: APIPhotoAnalysisService())
                        case .compareResults:
                            CompareResultsView()
                        case .beatYourScore:
                            BeatYourScoreView()
                        }
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(AppColors.accent)
        .onChange(of: flowViewModel.requestedTabIndex) { _, newValue in
            if let tab = newValue {
                selectedTab = tab
                flowViewModel.requestedTabIndex = nil
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppFlowViewModel())
        .environmentObject(HistoryViewModel())
}
