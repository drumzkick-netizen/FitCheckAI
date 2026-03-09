//
//  HistoryViewModel.swift
//  FitCheckAI
//

import Combine
import Foundation

/// A single entry in the unified history list (single-photo analysis, Photo Battle, or Beat Your Score).
enum HistoryRecord: Identifiable {
    case single(PhotoAnalysis)
    case battle(PhotoBattleResult)
    case beatYourScore(BeatYourScoreResult)

    var id: UUID {
        switch self {
        case .single(let item): return item.id
        case .battle(let b): return b.id
        case .beatYourScore(let r): return r.id
        }
    }

    var date: Date {
        switch self {
        case .single(let item): return item.date
        case .battle(let b): return b.date
        case .beatYourScore(let r): return r.date
        }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var items: [PhotoAnalysis] = []
    @Published var battleItems: [PhotoBattleResult] = []
    @Published var beatYourScoreItems: [BeatYourScoreResult] = []

    private let storage = HistoryStorageService()

    /// Unified list sorted by date (newest first) for the History tab.
    var mergedRecords: [HistoryRecord] {
        let single = items.map { HistoryRecord.single($0) }
        let battles = battleItems.map { HistoryRecord.battle($0) }
        let beatScore = beatYourScoreItems.map { HistoryRecord.beatYourScore($0) }
        return (single + battles + beatScore).sorted { $0.date > $1.date }
    }

    init() {
        load()
    }

    func load() {
        items = storage.loadHistory()
        items.sort { $0.date > $1.date }
        battleItems = storage.loadBattles()
        battleItems.sort { $0.date > $1.date }
        beatYourScoreItems = storage.loadBeatYourScore()
        beatYourScoreItems.sort { $0.date > $1.date }
    }

    func addAnalysis(imageData: Data, purpose: PhotoPurpose, result: AnalysisResult) {
        let item = PhotoAnalysis(
            imageData: imageData,
            purpose: purpose,
            result: result,
            date: Date()
        )
        do {
            try storage.addItem(item)
            load()
        } catch {
            print("[HistoryViewModel] Save failed: \(error.localizedDescription)")
        }
    }

    func addBattle(imageAData: Data, imageBData: Data, scoreA: Double, scoreB: Double, winner: CompareWinner) {
        let item = PhotoBattleResult(
            imageAData: imageAData,
            imageBData: imageBData,
            scoreA: scoreA,
            scoreB: scoreB,
            winner: winner
        )
        do {
            try storage.addBattle(item)
            load()
        } catch {
            print("[HistoryViewModel] Save battle failed: \(error.localizedDescription)")
        }
    }

    func addBeatYourScore(originalImageData: Data, newImageData: Data, originalScore: Double, newScore: Double) {
        let item = BeatYourScoreResult(
            originalImageData: originalImageData,
            newImageData: newImageData,
            originalScore: originalScore,
            newScore: newScore
        )
        do {
            try storage.addBeatYourScore(item)
            load()
        } catch {
            print("[HistoryViewModel] Save beat your score failed: \(error.localizedDescription)")
        }
    }

    /// Delete records by their indices in the current merged list.
    func delete(at offsets: IndexSet) {
        let records = mergedRecords
        var singleIdsToRemove: [UUID] = []
        var battleIdsToRemove: [UUID] = []
        var beatScoreIdsToRemove: [UUID] = []
        for index in offsets {
            switch records[index] {
            case .single(let item): singleIdsToRemove.append(item.id)
            case .battle(let b): battleIdsToRemove.append(b.id)
            case .beatYourScore(let r): beatScoreIdsToRemove.append(r.id)
            }
        }
        if !singleIdsToRemove.isEmpty {
            var updated = items
            for id in singleIdsToRemove { updated.removeAll { $0.id == id } }
            do { try storage.saveHistory(updated) } catch {
                print("[HistoryViewModel] Delete failed: \(error.localizedDescription)")
            }
        }
        if !battleIdsToRemove.isEmpty {
            var updated = battleItems
            for id in battleIdsToRemove { updated.removeAll { $0.id == id } }
            do { try storage.saveBattles(updated) } catch {
                print("[HistoryViewModel] Delete battle failed: \(error.localizedDescription)")
            }
        }
        if !beatScoreIdsToRemove.isEmpty {
            var updated = beatYourScoreItems
            for id in beatScoreIdsToRemove { updated.removeAll { $0.id == id } }
            do { try storage.saveBeatYourScore(updated) } catch {
                print("[HistoryViewModel] Delete beat your score failed: \(error.localizedDescription)")
            }
        }
        load()
    }

    /// Delete analyses by their indices in the items array (for sectioned list).
    func deleteAnalyses(at offsets: IndexSet) {
        let idsToRemove = offsets.map { items[$0].id }
        var updated = items
        for id in idsToRemove { updated.removeAll { $0.id == id } }
        do {
            try storage.saveHistory(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete failed: \(error.localizedDescription)")
        }
    }

    /// Delete battles by their indices in the battleItems array (for sectioned list).
    func deleteBattles(at offsets: IndexSet) {
        let idsToRemove = offsets.map { battleItems[$0].id }
        var updated = battleItems
        for id in idsToRemove { updated.removeAll { $0.id == id } }
        do {
            try storage.saveBattles(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete battle failed: \(error.localizedDescription)")
        }
    }

    /// Delete Beat Your Score entries by their indices in beatYourScoreItems.
    func deleteBeatYourScoreAt(offsets: IndexSet) {
        let idsToRemove = offsets.map { beatYourScoreItems[$0].id }
        var updated = beatYourScoreItems
        for id in idsToRemove { updated.removeAll { $0.id == id } }
        do {
            try storage.saveBeatYourScore(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete beat your score failed: \(error.localizedDescription)")
        }
    }

    /// Delete a single analysis by id (e.g. from detail view).
    func deleteAnalysis(id: UUID) {
        var updated = items
        updated.removeAll { $0.id == id }
        do {
            try storage.saveHistory(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete failed: \(error.localizedDescription)")
        }
    }

    /// Delete a single battle by id (e.g. from detail view).
    func deleteBattle(id: UUID) {
        var updated = battleItems
        updated.removeAll { $0.id == id }
        do {
            try storage.saveBattles(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete battle failed: \(error.localizedDescription)")
        }
    }

    func deleteBeatYourScore(id: UUID) {
        var updated = beatYourScoreItems
        updated.removeAll { $0.id == id }
        do {
            try storage.saveBeatYourScore(updated)
            load()
        } catch {
            print("[HistoryViewModel] Delete beat your score failed: \(error.localizedDescription)")
        }
    }

    func clearAll() {
        do {
            try storage.clearHistory()
            try storage.clearBattles()
            try storage.clearBeatYourScore()
            load()
        } catch {
            print("[HistoryViewModel] Clear failed: \(error.localizedDescription)")
        }
    }
}
