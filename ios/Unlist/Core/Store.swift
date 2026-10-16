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
        guard let decoded = try? JSONDecoder().decode(DataFile.self, from: data), decoded.version == 1 else {
            throw StoreError.corrupt("\(name) can't be read")
        }
        return decoded
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
        guard let bytes = try? Data(contentsOf: file) else {
            // Seeding here would let the next save overwrite the only good backup.
            if fm.fileExists(atPath: backup.path) { throw StoreError.corrupt("data.json is missing but a backup exists") }
            let fresh = DataFile.empty()
            try save(fresh)
            return fresh
        }
        return try parse(bytes, "data.json")
    }

    func save(_ data: DataFile) throws {
        try ensureDirectory()
        let bytes = try encode(data)
        if fm.fileExists(atPath: file.path) {
            if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
            try fm.copyItem(at: file, to: backup)
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
