//
//  AppGradients.swift
//  FitCheckAI
//

import SwiftUI

enum AppGradients {
    static let primary = LinearGradient(
        colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.9, green: 0.45, blue: 0.85)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let outfit = LinearGradient(
        colors: [Color(red: 0.5, green: 0.35, blue: 0.9), Color(red: 0.7, green: 0.5, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let dating = LinearGradient(
        colors: [Color(red: 0.9, green: 0.4, blue: 0.6), Color(red: 0.95, green: 0.5, blue: 0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let social = LinearGradient(
        colors: [Color(red: 0.3, green: 0.6, blue: 0.95), Color(red: 0.5, green: 0.8, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let professional = LinearGradient(
        colors: [Color(red: 0.25, green: 0.5, blue: 0.7), Color(red: 0.4, green: 0.65, blue: 0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let compare = LinearGradient(
        colors: [Color(red: 0.45, green: 0.55, blue: 0.9), Color(red: 0.6, green: 0.7, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func forPurpose(_ purpose: PhotoPurpose) -> LinearGradient {
        switch purpose {
        case .outfit: return outfit
        case .dating: return dating
        case .social: return social
        case .professional: return professional
        case .compare: return compare
        case .improveFit: return outfit
        }
    }
}
