import Foundation

/// The profile values a search template can use.
struct SearchValues: Equatable, Sendable {
    var first = ""
    var last = ""
    var middle = ""
    var city = ""
    var state = ""
    var stateName = ""
    var zip = ""

    init(profile: Profile) {
        let words = profile.fullName.split(whereSeparator: \.isWhitespace).map(String.init)
        if let f = words.first { first = f }
        if words.count > 1 {
            last = words[words.count - 1]
            middle = words[1..<(words.count - 1)].joined(separator: " ")
        }
        if let a = profile.addresses.first(where: \.current) ?? profile.addresses.first {
            city = a.city.trimmingCharacters(in: .whitespaces)
            state = a.state.trimmingCharacters(in: .whitespaces).uppercased()
            stateName = stateNames[state] ?? ""
            zip = a.zip.trimmingCharacters(in: .whitespaces)
        }
    }

    func value(_ name: String) -> String {
        switch name {
        case "first": first
        case "last": last
        case "middle": middle
        case "city": city
        case "state": state
        case "stateName": stateName
        case "zip": zip
        default: ""
        }
    }
}

enum SearchLink: Equatable, Sendable {
    /// Opens the owner's results directly.
    case direct(URL)
    /// The broker's plain search page; `missing` names profile fields that
    /// would allow a direct link ("city", "last name"…), empty when the broker
    /// has no template.
    case fallback(URL, missing: [String])
}

private let missingWords = ["first": "first name", "last": "last name", "city": "city",
                            "state": "state", "stateName": "state", "zip": "ZIP"]

private let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

/// Lowercase (or case-kept) words joined by "-", accents folded, apostrophes dropped.
func slug(_ s: String, keepCase: Bool) -> String {
    let folded = s.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
        .replacingOccurrences(of: "['’]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return keepCase ? folded : folded.lowercased()
}

func searchLink(for broker: Broker, profile: Profile) -> SearchLink {
    let page = URL(string: broker.searchUrl) ?? URL(string: "https://example.com")!
    guard let template = broker.searchTemplate else { return .fallback(page, missing: []) }

    let values = SearchValues(profile: profile)
    var missing: [String] = []
    var out = template
    for p in templatePlaceholders(template) {
        let raw = values.value(p.name)
        // A middle name is optional; everything else must be known.
        if raw.isEmpty, p.name != "middle", let word = missingWords[p.name], !missing.contains(word) {
            missing.append(word)
        }
        let filled: String
        switch p.modifier {
        case "slug": filled = slug(raw, keepCase: false)
        case "Slug": filled = slug(raw, keepCase: true)
        default: filled = raw.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
        }
        let token = "{" + p.name + (p.modifier.map { ":" + $0 } ?? "") + "}"
        out = out.replacingOccurrences(of: token, with: filled)
    }
    if !missing.isEmpty { return .fallback(page, missing: missing) }
    guard let url = URL(string: out) else { return .fallback(page, missing: []) }
    return .direct(url)
}

let stateNames: [String: String] = [
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
    "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia",
    "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois",
    "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana",
    "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
    "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
    "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
    "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia",
    "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
]
