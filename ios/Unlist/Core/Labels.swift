import Foundation

// Words shown to the owner (web/labels.ts). Symbols are SF Symbol names.

extension ViewStatus {
    var label: String {
        switch self {
        case .notChecked: "Not checked"
        case .found: "Found"
        case .requestSent: "Request sent"
        case .removed: "Confirmed removed"
        case .relisted: "Re-listed"
        case .due: "Due for recheck"
        }
    }

    /// One plain sentence explaining the status and what happens next.
    var help: String {
        switch self {
        case .notChecked: "You haven't searched this site for yourself yet."
        case .found: "Your information is listed here. Next, ask them to remove it."
        case .requestSent: "You've asked for removal. Waiting for the site to take your listing down."
        case .removed: "Your listing is gone. Unlist will remind you to check again in case it comes back."
        case .relisted: "Your listing came back. Send a new removal request."
        case .due: "It's time to search again and make sure your listing hasn't come back."
        }
    }

    var symbol: String {
        switch self {
        case .notChecked: "circle"
        case .found: "eye"
        case .requestSent: "paperplane"
        case .removed: "checkmark.circle"
        case .relisted: "exclamationmark.triangle"
        case .due: "clock"
        }
    }
}

extension Status {
    var label: String { ViewStatus(rawValue: rawValue)!.label }
}

extension RemovalMethod {
    var label: String {
        switch self {
        case .webForm: "Web form"
        case .email: "Email"
        case .phone: "Phone"
        case .mail: "Mail"
        case .idUpload: "ID upload"
        }
    }

    var symbol: String {
        switch self {
        case .webForm: "globe"
        case .email: "envelope"
        case .phone: "phone"
        case .mail: "mail.stack"
        case .idUpload: "person.text.rectangle"
        }
    }
}

extension RelistRisk {
    var label: String {
        switch self {
        case .low: "Rarely re-lists"
        case .medium: "Sometimes re-lists"
        case .high: "Often re-lists"
        }
    }
}

/// What the owner should do next for this broker, in a few words.
func nextStep(_ row: BrokerRow) -> String {
    let rec = row.record
    switch row.view {
    case .notChecked: return "Search for your listing"
    case .found: return "Send a removal request"
    case .requestSent: return rec?.requestSentAt.map { "Waiting since \(formatDate($0))" } ?? "Waiting for removal"
    case .removed: return rec?.recheckAt.map { "Recheck \(formatDate($0))" } ?? "Removed"
    case .due: return "Search again now"
    case .relisted: return "Send a new request"
    }
}
