import Foundation

/// Which profile value goes into which kind of form field.
func autofillValues(_ profile: Profile) -> [AutofillField: String] {
    func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    let names = SearchValues(profile: profile)
    let address = profile.addresses.first(where: \.current) ?? profile.addresses.first
    let all: [AutofillField: String] = [
        .fullName: profile.fullName.split(whereSeparator: \.isWhitespace).joined(separator: " "),
        .firstName: names.first,
        .lastName: names.last,
        .email: profile.emails.map(trim).first { !$0.isEmpty } ?? "",
        .phone: profile.phones.map(trim).first { !$0.isEmpty } ?? "",
        .street: trim(address?.street ?? ""),
        .city: trim(address?.city ?? ""),
        .state: stateCode(address?.state ?? ""),
        .zip: trim(address?.zip ?? ""),
    ]
    return all.filter { !$0.value.isEmpty }
}

/// The JSON handed to `unlistFill` in the page.
func autofillPayload(_ profile: Profile, selectors: [AutofillField: String]?) -> String {
    let values = Dictionary(uniqueKeysWithValues: autofillValues(profile).map { ($0.key.rawValue, $0.value) })
    let sel = Dictionary(uniqueKeysWithValues: (selectors ?? [:]).map { ($0.key.rawValue, $0.value) })
    let state = values["state"] ?? ""
    let payload: [String: Any] = ["values": values, "selectors": sel, "stateName": stateNames[state] ?? ""]
    let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

/// The fill script bundled with the app (Resources/autofill.js).
enum AutofillScript {
    static let source: String = {
        guard let url = Bundle.main.url(forResource: "autofill", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()
}
