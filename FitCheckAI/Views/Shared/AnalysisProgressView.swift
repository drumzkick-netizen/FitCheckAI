//
//  AnalysisProgressView.swift
//  FitCheckAI
//

import SwiftUI

/// Progressive AI analysis animation: steps appear sequentially with a short delay and show a checkmark when completed.
/// Includes a simulated progress bar that advances while analysis is running and completes when the parent marks it done.
/// Use during the analysis loading state while waiting for the API response.
struct AnalysisProgressView: View {
    private static let steps = [
        "Detecting outfit",
        "Evaluating style",
        "Analyzing composition",
        "Checking color balance",
        "Generating feedback"
    ]
    private static let stepInterval: TimeInterval = 0.8
    private static let progressTickInterval: TimeInterval = 0.15
    private static let minSimulatedProgressCap: Double = 0.88
    private static let maxSimulatedProgressCap: Double = 0.96

    /// When true, the progress bar will animate to 100% and the step timer will naturally finish.
    @Binding var isComplete: Bool

    @State private var currentIndex: Int = 0
    @State private var stepTimer: Timer?
    @State private var progressTimer: Timer?
    @State private var progress: Double = 0.08
    @State private var sessionConfigured: Bool = false
    @State private var sessionMaxProgress: Double = maxSimulatedProgressCap
    @State private var sessionPaceMultiplier: Double = 1.0
    @State private var microVariationPhase: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressSection
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, title in
                    if index <= currentIndex {
                        AnalysisStepRow(
                            title: title,
                            isComplete: index < currentIndex,
                            isActive: index == currentIndex
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .onAppear {
            startStepTimer()
            startProgressTimer()
        }
        .onDisappear {
            stopStepTimer()
            stopProgressTimer()
        }
        .onChange(of: isComplete) { _, newValue in
            if newValue {
                // Smoothly fill to 100% once the real analysis result arrives.
                withAnimation(.easeOut(duration: 0.35)) {
                    progress = 1.0
                }
                stopProgressTimer()
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .tint(AppColors.accent)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 1, y: 1.4, anchor: .center)
            HStack {
                Text(progressStatusText)
                    .font(.caption)
                    .foregroundStyle(AppColors.mutedText)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(AppColors.mutedText.opacity(0.9))
            }
        }
    }

    private var progressStatusText: String {
        if isComplete {
            return "Wrapping up your analysis..."
        } else if progress > 0.8 {
            return "Almost done..."
        } else {
            return "Analyzing your fit..."
        }
    }

    private func startStepTimer() {
        stopStepTimer()
        currentIndex = 0
        stepTimer = Timer.scheduledTimer(withTimeInterval: Self.stepInterval, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.35)) {
                if currentIndex < Self.steps.count - 1 {
                    currentIndex += 1
                } else {
                    stopStepTimer()
                }
            }
        }
        if let stepTimer {
            RunLoop.main.add(stepTimer, forMode: .common)
        }
    }

    private func stopStepTimer() {
        stepTimer?.invalidate()
        stepTimer = nil
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progress = 0.08
        microVariationPhase = Double.random(in: 0...(2 * .pi))
        progressTimer = Timer.scheduledTimer(withTimeInterval: Self.progressTickInterval, repeats: true) { _ in
            if !sessionConfigured {
                configureSessionProgressProfile()
            }
            guard !isComplete else { return }

            let cap = sessionMaxProgress
            guard progress < cap else { return }

            let remaining = cap - progress
            // Move faster at the beginning, then slow as we approach the per-session cap.
            let baseRate = 0.12 * sessionPaceMultiplier
            var delta = remaining * baseRate

            // Subtle micro-variation so the motion feels less robotic,
            // while remaining smooth and strictly increasing.
            microVariationPhase += 0.35
            let microFactor = 1.0 + 0.05 * sin(microVariationPhase)
            delta *= microFactor

            let minDelta = 0.004 * sessionPaceMultiplier
            let maxDelta = 0.028 * sessionPaceMultiplier
            if delta < minDelta { delta = minDelta }
            if delta > maxDelta { delta = maxDelta }
            withAnimation(.linear(duration: Self.progressTickInterval)) {
                progress = min(progress + delta, cap)
            }
        }
        if let progressTimer {
            RunLoop.main.add(progressTimer, forMode: .common)
        }
    }

    private func configureSessionProgressProfile() {
        sessionConfigured = true
        // Soft cap and pacing vary slightly per session so the progress does not always stall at the same point.
        sessionMaxProgress = Double.random(in: Self.minSimulatedProgressCap...Self.maxSimulatedProgressCap)
        sessionPaceMultiplier = Double.random(in: 0.9...1.15)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        AnalysisProgressView(isComplete: .constant(false))
            .padding(.horizontal, 24)
    }
    .preferredColorScheme(.dark)
}
