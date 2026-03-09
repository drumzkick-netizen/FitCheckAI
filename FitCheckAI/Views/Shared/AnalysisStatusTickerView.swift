//
//  AnalysisStatusTickerView.swift
//  FitCheckAI
//

import SwiftUI

struct AnalysisStatusTickerView: View {
    private let messages: [String] = [
        "Detecting face...",
        "Analyzing lighting...",
        "Evaluating composition...",
        "Checking presentation...",
        "Scoring confidence..."
    ]

    @State private var currentIndex = 0
    @State private var tickerTimer: Timer?
    private let cycleInterval: TimeInterval = 1.2

    var body: some View {
        Text(messages[currentIndex])
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.mutedText.opacity(0.95))
            .animation(.easeInOut(duration: 0.35), value: currentIndex)
            .transition(.opacity)
            .contentTransition(.opacity)
            .id(currentIndex)
            .onAppear {
                tickerTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentIndex = (currentIndex + 1) % messages.count
                    }
                }
                RunLoop.main.add(tickerTimer!, forMode: .common)
            }
            .onDisappear {
                tickerTimer?.invalidate()
                tickerTimer = nil
            }
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        AnalysisStatusTickerView()
    }
    .preferredColorScheme(.dark)
}
