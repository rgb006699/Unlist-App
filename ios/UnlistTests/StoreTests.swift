import Foundation
import Testing
@testable import Unlist

@Suite struct StoreTests {
    let dir: URL
    let store: DataStore

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("unlist-store-\(UUID().uuidString)")
        store = DataStore(directory: dir)
    }

    private func url(_ name: String) -> URL { dir.appendingPathComponent(name) }
    private func read(_ name: String) throws -> DataFile { try JSONDecoder().decode(DataFile.self, from: Data(contentsOf: url(name))) }
    private func files() -> [String] { (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] }
    private func named(_ name: String) -> DataFile { var d = DataFile.empty(); d.profile.fullName = name; return d }

    @Test func firstLoadCreatesAnEmptyFile() throws {
        #expect(try store.load() == .empty())
        #expect(try read("data.json") == .empty())
    }

    @Test func saveKeepsABackupAndNoTempFile() throws {
        try store.save(named("First"))
        try store.save(named("Second"))
        #expect(try read("data.json").profile.fullName == "Second")
        #expect(try read("data.json.bak").profile.fullName == "First")
        #expect(!files().contains("data.json.tmp"))
    }

    @Test func badJSONIsCorruptAndLeftUntouched() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url("data.json"))
        #expect(throws: StoreError.self) { try store.load() }
        #expect(String(decoding: try Data(contentsOf: url("data.json")), as: UTF8.self) == "{not json")
    }

    @Test func wrongVersionIsCorrupt() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"version":2}"#.utf8).write(to: url("data.json"))
        #expect { try store.load() } throws: { ($0 as? StoreError).map { if case .corrupt = $0 { true } else { false } } ?? false }
    }

    @Test func restoreKeepsTheCorruptFile() throws {
        try store.save(named("Saved"))
        try store.save(named("Saved"))
        try Data("{hand edit,}".utf8).write(to: url("data.json"))
        #expect(try store.restore().profile.fullName == "Saved")
        #expect(try store.load().profile.fullName == "Saved")
        let kept = files().filter { $0.hasPrefix("data.json.corrupt-") }
        #expect(kept.count == 1)
        #expect(String(decoding: try Data(contentsOf: url(kept[0])), as: UTF8.self) == "{hand edit,}")
    }

    @Test func restoreWithoutBackupFails() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: url("data.json"))
        #expect(throws: StoreError.noBackup) { try store.restore() }
    }

    @Test func missingFileWithBackupIsReportedNotReseeded() throws {
        try store.save(named("Keep"))
        try store.save(named("Keep"))
        try FileManager.default.removeItem(at: url("data.json"))
        #expect(throws: StoreError.self) { try store.load() }
        #expect(try read("data.json.bak").profile.fullName == "Keep")
        #expect(try store.restore().profile.fullName == "Keep")
    }

    @Test func restoreRefusesWhenDataIsReadable() throws {
        try store.save(named("First"))
        try store.save(named("Second"))
        #expect(throws: StoreError.nothingToRestore) { try store.restore() }
        #expect(try store.load().profile.fullName == "Second")
        #expect(!files().contains { $0.hasPrefix("data.json.corrupt-") })
    }

    @Test func orphanRecordsSurviveASave() throws {
        var d = DataFile.empty()
        d.records["retired"] = applyStatus(nil, .found, today: "2026-10-15", recheckDays: 90)
        try store.save(d)
        #expect(try store.load().records["retired"] != nil)
    }
}
