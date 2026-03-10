//
//  AppDelegate.swift
//  FitCheckAI
//

import UIKit

/// When true, the app reports portrait-only so the custom camera screen does not rotate.
enum CameraOrientationLock {
    static var lockPortrait = false
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if CameraOrientationLock.lockPortrait {
            return .portrait
        }
        return .all
    }
}
