//
//  FitCheckAIApp.swift
//  FitCheckAI
//

import SwiftUI

@main
struct FitCheckAIApp: App {
    @StateObject private var flowViewModel = AppFlowViewModel()
    @StateObject private var historyViewModel = HistoryViewModel()
    @State private var showSplash = true

    init() {
        AppConfig.logResolvedConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppBackground()
                RootView()
                    .environmentObject(flowViewModel)
                    .environmentObject(historyViewModel)
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .animation(.easeOut(duration: 0.35), value: showSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + SplashView.displayDuration) {
                    showSplash = false
                }
            }
        }
    }
}
