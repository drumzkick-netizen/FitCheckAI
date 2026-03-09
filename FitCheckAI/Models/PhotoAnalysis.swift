//
//  PhotoAnalysis.swift
//  FitCheckAI
//

import Foundation

struct PhotoAnalysis: Identifiable, Codable, Hashable {
    let id: UUID
    let imageData: Data
    let purpose: PhotoPurpose
    let result: AnalysisResult
    let date: Date

    init(id: UUID = UUID(), imageData: Data, purpose: PhotoPurpose, result: AnalysisResult, date: Date) {
        self.id = id
        self.imageData = imageData
        self.purpose = purpose
        self.result = result
        self.date = date
    }
}
