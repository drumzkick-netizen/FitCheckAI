//
//  AppFlowViewModel.swift
//  FitCheckAI
//

import Combine
import SwiftUI
import UIKit

enum CompareWinner: String, Hashable, Codable {
    case photoA = "photoA"
    case photoB = "photoB"
    case tie = "tie"
}

enum FlowRoute: Hashable {
    case capture
    case cameraCapture
    case purpose
    case adjustPhoto
    case analyze
    case results
    case compareCapture
    case compareAnalyze
    case compareResults
    case beatYourScore
}

final class AppFlowViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var selectedImageData: Data?
    @Published var selectedPurpose: PhotoPurpose?
    @Published var latestResult: AnalysisResult?
    @Published var navigationPath: [FlowRoute] = []

    @Published var compareImage: UIImage?
    @Published var compareImageData: Data?
    @Published var compareFirstResult: AnalysisResult?
    @Published var compareSecondResult: AnalysisResult?
    @Published var compareWinner: CompareWinner?

    /// Beat Your Score: second photo and its analysis result. Original = selectedImage + latestResult.
    @Published var beatScoreSecondImage: UIImage?
    @Published var beatScoreSecondImageData: Data?
    @Published var beatScoreSecondResult: AnalysisResult?

    /// When set, RootView should switch to this tab index (e.g. 0 for Home). Used by History empty state CTAs.
    @Published var requestedTabIndex: Int?

    /// When true, CaptureView should present camera on appear (e.g. from Home "Take Photo"). Cleared by CaptureView.
    @Published var preferCameraOnNextCapture = false
    /// When true, CaptureView should present library picker on appear (e.g. from Home "Upload Photo"). Cleared by CaptureView.
    @Published var preferLibraryOnNextCapture = false

    init() {
        self.selectedImage = nil
        self.selectedImageData = nil
        self.selectedPurpose = nil
        self.latestResult = nil
        self.compareImage = nil
        self.compareImageData = nil
        self.compareFirstResult = nil
        self.compareSecondResult = nil
        self.compareWinner = nil
        self.beatScoreSecondImage = nil
        self.beatScoreSecondImageData = nil
        self.beatScoreSecondResult = nil
    }

    func clearBeatScoreState() {
        beatScoreSecondImage = nil
        beatScoreSecondImageData = nil
        beatScoreSecondResult = nil
    }

    func resetFlow() {
        selectedImage = nil
        selectedImageData = nil
        selectedPurpose = nil
        latestResult = nil
        compareImage = nil
        compareImageData = nil
        compareFirstResult = nil
        compareSecondResult = nil
        compareWinner = nil
        beatScoreSecondImage = nil
        beatScoreSecondImageData = nil
        beatScoreSecondResult = nil
        navigationPath = []
    }

    /// Clears only single-photo flow state so the next time the user enters that flow they see a blank photo selection. Call when starting the single-photo Analyze flow from Home. Does not touch compare/Photo Battle state.
    func clearSinglePhotoFlowState() {
        selectedImage = nil
        selectedImageData = nil
    }
}
