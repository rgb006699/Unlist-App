import Foundation

enum StoreError: Error, Equatable, Sendable {
    case corrupt(String)
    case nothingToRestore
    case noBackup
}

/// The owner's data file on this iPhone, with the same safety rules as the
/// web server's store: atomic saves, a one-step backup, and a restore that
/// never throws away an unreadable file.
struct DataStore: Sendable {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func appDefault() -> DataStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DataStore(directory: base.appendingPathComponent("Unlist", isDirectory: true))
    }

    private var file: URL { directory.appendingPathComponent("data.json") }
    private var backup: URL { directory.appendingPathComponent("data.json.bak") }
    private var temp: URL { directory.appendingPathComponent("data.json.tmp") }
    private var fm: FileManager { .default }

    private func ensureDirectory() throws {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func parse(_ data: Data, _ name: String) throws -> DataFile {
        guard let decoded = try? JSONDecoder().decode(DataFile.self, from: data), decoded.version == 1,
              decoded.settings.recheckDays > 0, decoded.records.values.allSatisfy(Self.datesAreValid) else {
            throw StoreError.corrupt("\(name) can't be read")
        }
        return decoded
    }

    /// Same date rules as the web schema: every date is a real YYYY-MM-DD.
    private static func datesAreValid(_ r: BrokerRecord) -> Bool {
        [r.requestSentAt, r.removedAt, r.recheckAt].allSatisfy { $0.map(isISODate) ?? true }
            && r.history.allSatisfy { isISODate($0.at) }
    }

    private func encode(_ data: DataFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(data)
    }

    /// Writes `bytes` to data.json via a temp file, so a crash never leaves half a file.
    private func replaceFile(with bytes: Data) throws {
        try bytes.write(to: temp, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        if fm.fileExists(atPath: file.path) {
            _ = try fm.replaceItemAt(file, withItemAt: temp)
        } else {
            try fm.moveItem(at: temp, to: file)
        }
    }

    func load() throws -> DataFile {
        try ensureDirectory()
        if fm.fileExists(atPath: file.path) {
            // Exists but can't be read (e.g. the phone hasn't been unlocked since
            // a restart): report it, never replace it with an empty file.
            guard let bytes = try? Data(contentsOf: file) else { throw StoreError.corrupt("data.json can't be read right now") }
            return try parse(bytes, "data.json")
        }
        // Seeding here would let the next save overwrite the only good backup.
        if fm.fileExists(atPath: backup.path) { throw StoreError.corrupt("data.json is missing but a backup exists") }
        let fresh = DataFile.empty()
        try save(fresh)
        return fresh
    }

    func save(_ data: DataFile) throws {
        try ensureDirectory()
        let bytes = try encode(data)
        if fm.fileExists(atPath: file.path) {
            // Copy, then swap in, so a failed copy never leaves us without a backup.
            let backupTemp = directory.appendingPathComponent("data.json.bak.tmp")
            if fm.fileExists(atPath: backupTemp.path) { try fm.removeItem(at: backupTemp) }
            try fm.copyItem(at: file, to: backupTemp)
            if fm.fileExists(atPath: backup.path) {
                _ = try fm.replaceItemAt(backup, withItemAt: backupTemp)
            } else {
                try fm.moveItem(at: backupTemp, to: backup)
            }
        }
        try replaceFile(with: bytes)
    }

    /// Replaces a missing or unreadable data.json with the backup, keeping the
    /// unreadable file as data.json.corrupt-<time>.
    func restore() throws -> DataFile {
        try ensureDirectory()
        if let current = try? Data(contentsOf: file), (try? parse(current, "data.json")) != nil {
            throw StoreError.nothingToRestore
        }
        guard let saved = try? Data(contentsOf: backup) else { throw StoreError.noBackup }
        let data = try parse(saved, "data.json.bak")
        if fm.fileExists(atPath: file.path) {
            let stamp = Int(Date().timeIntervalSince1970 * 1000)
            try fm.moveItem(at: file, to: directory.appendingPathComponent("data.json.corrupt-\(stamp)"))
        }
        try replaceFile(with: saved)
        return data
    }
}
