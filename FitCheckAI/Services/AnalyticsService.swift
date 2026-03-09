//
//  AnalyticsService.swift
//  FitCheckAI
//

import Foundation

/// Lightweight analytics hook points for key actions. Stub implementation; replace with real analytics later.
/// Do not add external SDK complexity—keep it simple for future instrumentation.
enum AnalyticsService {
    static func log(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event.name)")
        #endif
        // TODO: Send to analytics provider when integrated.
    }

    enum AnalyticsEvent {
        case analysisStarted
        case analysisCompleted
        case photoBattleStarted
        case photoBattleCompleted
        case shareScoreCard
        case shareBattleCard
        case improveMyFitTapped
        case beatYourScoreStarted

        var name: String {
            switch self {
            case .analysisStarted: return "analysis_started"
            case .analysisCompleted: return "analysis_completed"
            case .photoBattleStarted: return "photo_battle_started"
            case .photoBattleCompleted: return "photo_battle_completed"
            case .shareScoreCard: return "share_score_card"
            case .shareBattleCard: return "share_battle_card"
            case .improveMyFitTapped: return "improve_my_fit_tapped"
            case .beatYourScoreStarted: return "beat_your_score_started"
            }
        }
    }
}
