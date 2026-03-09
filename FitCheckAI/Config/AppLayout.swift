//
//  AppLayout.swift
//  FitCheckAI
//

import SwiftUI

/// Shared layout constants for consistent spacing across the app.
enum AppLayout {
    /// Standard horizontal content padding for primary screens and cards.
    /// Used for the main outer content column on primary screens.
    static let screenHorizontalPadding: CGFloat = 26
    /// Alias for older uses; kept for compatibility with existing views.
    static let horizontalPadding: CGFloat = screenHorizontalPadding
}

extension View {
    /// Applies the shared app screen content layout: a consistent horizontal inset for
    /// main screen content. Use this on the outer VStack inside ScrollViews.
    func appScreenContent() -> some View {
        self
            .padding(.horizontal, AppLayout.screenHorizontalPadding)
    }
}

