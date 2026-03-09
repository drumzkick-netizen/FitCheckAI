//
//  ShareCardRenderer.swift
//  FitCheckAI
//

import SwiftUI
import UIKit

/// Renders the Fit Score Share Card (1080×1920) to a UIImage for sharing via UIActivityViewController.
enum ShareCardRenderer {
    /// Renders the share card view to a UIImage. Returns nil if rendering fails.
    /// Use the returned image with ShareSheet / UIActivityViewController.
    static func renderShareCard(image: UIImage, result: AnalysisResult) -> UIImage? {
        let card = FitScoreShareCardView(image: image, result: result)
            .preferredColorScheme(.dark)
        return ViewImageRenderer.render(
            card,
            width: FitScoreShareCardView.designWidth,
            height: FitScoreShareCardView.designHeight,
            scale: 1
        )
    }
}
