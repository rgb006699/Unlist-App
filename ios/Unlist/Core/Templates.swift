import Foundation

// Request email templates — same wording as the web app (shared/templates.ts).
// Edit freely; it is a starting point, not legal advice.

enum TemplateID: String, CaseIterable, Identifiable, Sendable {
    case tdpsa, general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tdpsa: "Texas (TDPSA)"
        case .general: "General"
        }
    }
}

private func format(_ a: Address) -> String {
    let stateZip = [a.state, a.zip].filter { !$0.isEmpty }.joined(separator: " ")
    return [a.street, a.city, stateZip].filter { !$0.isEmpty }.joined(separator: ", ")
}

private func detailLines(_ profile: Profile, listingUrl: String) -> [String] {
    var lines: [String] = []
    func add(_ label: String, _ values: [String]) {
        let v = values.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !v.isEmpty { lines.append("\(label): \(v.joined(separator: "; "))") }
    }
    add("Full name", [profile.fullName])
    add("Other names", profile.aliases)
    let current = profile.addresses.filter(\.current).map(format)
    let others = profile.addresses.filter { !$0.current }.map(format)
    if current.isEmpty {
        add("Addresses", others)
    } else {
        add("Current address", current)
        add("Previous addresses", others)
    }
    add("Phone numbers", profile.phones)
    add("Email addresses", profile.emails)
    add("Page where my information appears", [listingUrl])
    return lines
}

private func closing(_ profile: Profile) -> String {
    let name = profile.fullName.trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? "Thank you." : "Thank you,\n\(name)"
}

func fillTemplate(_ id: TemplateID, profile: Profile, broker: Broker, listingUrl: String) -> (subject: String, body: String) {
    let details = detailLines(profile, listingUrl: listingUrl)
    let detailBlock = details.isEmpty ? [] : [details.joined(separator: "\n")]

    switch id {
    case .tdpsa:
        let paragraphs = [
            "To the privacy team at \(broker.name),",
            "I am a Texas resident. Under the Texas Data Privacy and Security Act, I am exercising my right to have my personal data deleted. Please delete all personal data you hold about me, stop selling or sharing it, and remove any public profile or listing about me. My identifying details are below.",
        ] + detailBlock + [
            "Please use these details only to find and delete my records. The Texas Data Privacy and Security Act requires a response within 45 days. Please confirm in writing when the deletion is complete.",
            closing(profile),
        ]
        return ("Request to delete my personal data — Texas Data Privacy and Security Act", paragraphs.joined(separator: "\n\n"))
    case .general:
        let paragraphs = [
            "Hello \(broker.name) team,",
            "I am asking you to remove my personal information from your website and records, and to stop selling or sharing it. My identifying details are below.",
        ] + detailBlock + [
            "Please use these details only to find and remove my records, and confirm in writing when this is done.",
            closing(profile),
        ]
        return ("Request to remove my personal information", paragraphs.joined(separator: "\n\n"))
    }
}

/// Same characters as JavaScript's encodeURIComponent leaves unescaped.
private let uriComponentAllowed = CharacterSet(charactersIn:
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

private func encode(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) ?? ""
}

func mailtoURL(to: String?, subject: String, body: String) -> URL {
    URL(string: "mailto:\(to ?? "")?subject=\(encode(subject))&body=\(encode(body))")!
}
