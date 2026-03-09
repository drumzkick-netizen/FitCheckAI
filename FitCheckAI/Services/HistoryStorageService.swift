//
//  HistoryStorageService.swift
//  FitCheckAI
//

import Foundation

final class HistoryStorageService {
    private let fileName = "photo_analysis_history.json"
    private let battlesFileName = "photo_battle_history.json"
    private let beatYourScoreFileName = "beat_your_score_history.json"

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }

    private var battlesFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(battlesFileName)
    }

    private var beatYourScoreFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(beatYourScoreFileName)
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func loadHistory() -> [PhotoAnalysis] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let items = try decoder.decode([PhotoAnalysis].self, from: data)
            return items
        } catch {
            print("[HistoryStorage] Load failed: \(error.localizedDescription)")
            return []
        }
    }

    func saveHistory(_ items: [PhotoAnalysis]) throws {
        let data = try encoder.encode(items)
        try data.write(to: fileURL)
    }

    func addItem(_ item: PhotoAnalysis) throws {
        var items = loadHistory()
        items.insert(item, at: 0)
        try saveHistory(items)
    }

    func deleteItem(id: UUID) throws {
        var items = loadHistory()
        items.removeAll { $0.id == id }
        try saveHistory(items)
    }

    func clearHistory() throws {
        try saveHistory([])
    }

    // MARK: - Photo Battle history

    func loadBattles() -> [PhotoBattleResult] {
        guard FileManager.default.fileExists(atPath: battlesFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: battlesFileURL)
            let items = try decoder.decode([PhotoBattleResult].self, from: data)
            return items
        } catch {
            print("[HistoryStorage] Load battles failed: \(error.localizedDescription)")
            return []
        }
    }

    func saveBattles(_ items: [PhotoBattleResult]) throws {
        let data = try encoder.encode(items)
        try data.write(to: battlesFileURL)
    }

    func addBattle(_ item: PhotoBattleResult) throws {
        var items = loadBattles()
        items.insert(item, at: 0)
        try saveBattles(items)
    }

    func deleteBattle(id: UUID) throws {
        var items = loadBattles()
        items.removeAll { $0.id == id }
        try saveBattles(items)
    }

    func clearBattles() throws {
        try saveBattles([])
    }

    // MARK: - Beat Your Score history

    func loadBeatYourScore() -> [BeatYourScoreResult] {
        guard FileManager.default.fileExists(atPath: beatYourScoreFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: beatYourScoreFileURL)
            let items = try decoder.decode([BeatYourScoreResult].self, from: data)
            return items
        } catch {
            print("[HistoryStorage] Load beat your score failed: \(error.localizedDescription)")
            return []
        }
    }

    func saveBeatYourScore(_ items: [BeatYourScoreResult]) throws {
        let data = try encoder.encode(items)
        try data.write(to: beatYourScoreFileURL)
    }

    func addBeatYourScore(_ item: BeatYourScoreResult) throws {
        var items = loadBeatYourScore()
        items.insert(item, at: 0)
        try saveBeatYourScore(items)
    }

    func deleteBeatYourScore(id: UUID) throws {
        var items = loadBeatYourScore()
        items.removeAll { $0.id == id }
        try saveBeatYourScore(items)
    }

    func clearBeatYourScore() throws {
        try saveBeatYourScore([])
    }
}
