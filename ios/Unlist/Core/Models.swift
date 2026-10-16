import Foundation

// Same shapes and JSON keys as the web app (shared/types.ts), so a data file
// written by either app can be read by the other.

enum RemovalMethod: String, Codable, CaseIterable, Sendable {
    case webForm = "web_form", email, phone, mail, idUpload = "id_upload"
}

enum RelistRisk: String, Codable, Sendable {
    case low, medium, high
}

enum Status: String, Codable, CaseIterable, Sendable {
    case found, requestSent = "request_sent", removed, relisted
}

enum ViewStatus: String, CaseIterable, Sendable {
    case notChecked = "not_checked", found, requestSent = "request_sent", removed, relisted, due
}

/// A history entry is a status change or a "still removed" recheck.
enum HistoryStatus: Codable, Equatable, Sendable {
    case status(Status)
    case rechecked

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if raw == "rechecked" {
            self = .rechecked
        } else if let status = Status(rawValue: raw) {
            self = .status(status)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown status \(raw)"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .status(let s): try c.encode(s.rawValue)
        case .rechecked: try c.encode("rechecked")
        }
    }
}

struct Broker: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let searchUrl: String
    let optOutUrl: String
    let method: RemovalMethod
    let optOutEmail: String?
    let needsCaptcha: Bool
    let needsEmailConfirm: Bool
    let needsId: Bool
    let relistRisk: RelistRisk
    let steps: [String]
    let lastVerified: String
}

struct Address: Codable, Hashable, Sendable {
    var street = ""
    var city = ""
    var state = "TX"
    var zip = ""
    var current = false
}

struct Profile: Codable, Equatable, Sendable {
    var fullName: String
    var aliases: [String]
    var addresses: [Address]
    var phones: [String]
    var emails: [String]

    static let empty = Profile(fullName: "", aliases: [], addresses: [], phones: [], emails: [])
}

struct HistoryEntry: Codable, Equatable, Sendable {
    let at: String
    let status: HistoryStatus
}

struct BrokerRecord: Codable, Equatable, Sendable {
    var status: Status
    var listingUrl: String
    var notes: String
    var requestSentAt: String?
    var removedAt: String?
    var recheckAt: String?
    var history: [HistoryEntry]
}

extension BrokerRecord {
    private enum CodingKeys: String, CodingKey {
        case status, listingUrl, notes, requestSentAt, removedAt, recheckAt, history
    }

    // Empty dates are written as null (not left out), like the web app.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encode(listingUrl, forKey: .listingUrl)
        try c.encode(notes, forKey: .notes)
        try c.encode(requestSentAt, forKey: .requestSentAt)
        try c.encode(removedAt, forKey: .removedAt)
        try c.encode(recheckAt, forKey: .recheckAt)
        try c.encode(history, forKey: .history)
    }
}

struct Settings: Codable, Equatable, Sendable {
    var recheckDays = 90
}

struct DataFile: Codable, Equatable, Sendable {
    var version = 1
    var profile: Profile
    var settings: Settings
    var records: [String: BrokerRecord]

    static func empty() -> DataFile {
        DataFile(profile: .empty, settings: Settings(), records: [:])
    }
}

struct Progress: Equatable, Sendable {
    let total: Int
    let removed: Int
    let pending: Int
    let due: Int
    let notChecked: Int
}

/// Trims every field and drops empty rows, including address rows with
/// nothing but the default state filled in (web Profile save rules).
func cleanProfile(_ p: Profile) -> Profile {
    func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    func list(_ xs: [String]) -> [String] { xs.map(trim).filter { !$0.isEmpty } }
    return Profile(
        fullName: trim(p.fullName),
        aliases: list(p.aliases),
        addresses: p.addresses
            .map { Address(street: trim($0.street), city: trim($0.city), state: trim($0.state), zip: trim($0.zip), current: $0.current) }
            .filter { !$0.street.isEmpty || !$0.city.isEmpty || !$0.zip.isEmpty },
        phones: list(p.phones),
        emails: list(p.emails)
    )
}
