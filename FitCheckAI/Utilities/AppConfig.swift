//
//  AppConfig.swift
//  FitCheckAI
//

import Foundation

// MARK: - Runtime simulator detection
// Use runtime check so the simulator always uses 127.0.0.1. Two checks:
// 1) SIMULATOR_DEVICE_NAME is set by the simulator runtime.
// 2) Bundle path contains "CoreSimulator" as fallback (e.g. if env var is missing).
private enum SimulatorCheck {
    static var isSimulator: Bool {
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            return true
        }
        return Bundle.main.bundlePath.contains("CoreSimulator")
    }
}

enum AppEnvironment: String, CaseIterable {
    case local
    case development
    case production

    var backendBaseURL: String {
        switch self {
        case .local:
            if SimulatorCheck.isSimulator {
                return AppConfig.simulatorBackendBaseURL
            }
            return AppConfig.localDeviceBackendBaseURL
        case .development:
            return "https://api-dev.fitcheckai.com"
        case .production:
            return "https://fitcheckai-as61.onrender.com"
        }
    }

    var analyzePhotoPath: String {
        "/analyze-photo"
    }

    var analyzePhotoURL: String {
        backendBaseURL + analyzePhotoPath
    }
}

enum AppConfig {
    /// Simulator base URL. Simulator and Mac share the same host, so 127.0.0.1 works.
    static let simulatorBackendBaseURL = "http://127.0.0.1:3000"

    /// Environment selection: always use production backend.
    static var currentEnvironment: AppEnvironment = .production

    /// For local env on a physical device: base URL using Mac's LAN IP from Info.plist key `DevBackendHost`.
    /// Set DevBackendHost to your Mac's IP (e.g. 192.168.1.100) so the device can reach the backend on the same Wi‑Fi.
    static var localDeviceBackendBaseURL: String {
        let host = (Bundle.main.infoDictionary?["DevBackendHost"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let use = host.flatMap { $0.isEmpty ? nil : $0 } ?? "127.0.0.1"
        if use == "127.0.0.1" {
            print("[AppConfig] DevBackendHost not set in Info.plist — set to your Mac's LAN IP (e.g. 192.168.1.x) for real-device testing.")
        }
        return "http://\(use):3000"
    }

    static var backendBaseURL: String {
        currentEnvironment.backendBaseURL
    }

    static var analyzePhotoURL: String {
        currentEnvironment.analyzePhotoURL
    }

    /// Call at app launch to log resolved backend URL. Use this to verify simulator vs device behavior.
    static func logResolvedConfiguration() {
        let env = currentEnvironment.rawValue
        let isSim = SimulatorCheck.isSimulator
        let base = backendBaseURL
        let full = analyzePhotoURL
        print("[AppConfig] currentEnvironment: \(env), isSimulator: \(isSim)")
        print("[AppConfig] Resolved backend base URL: \(base)")
        print("[AppConfig] Resolved analyze photo URL: \(full)")
    }
}
