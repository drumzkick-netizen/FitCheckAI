//
//  AppMotion.swift
//  FitCheckAI
//

import SwiftUI

enum AppMotion {
    static let standardEase = Animation.easeInOut(duration: 0.35)
    static let standardEaseSlow = Animation.easeInOut(duration: 0.5)
    static let springTap = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let slowPulse = Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true)
    static let fadeSlideDuration: Double = 0.4
    static let staggerDelay: Double = 0.06
}
