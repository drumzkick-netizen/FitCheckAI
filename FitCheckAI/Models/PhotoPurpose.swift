//
//  PhotoPurpose.swift
//  FitCheckAI
//

import Foundation

enum PhotoPurpose: String, CaseIterable, Identifiable, Codable {
    case outfit
    case dating
    case social
    case professional
    case compare
    /// Used only for "Improve My Fit" request from the result screen; not shown in purpose picker.
    case improveFit = "improve_fit"

    var id: String { rawValue }
}
