import Foundation

// Readable dates (web/format.ts). Formatted by hand so output never depends on
// the device locale or time zone and matches the web app.

private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

private func parts(_ iso: String) -> (Int, Int, Int) {
    let p = iso.split(separator: "-").compactMap { Int($0) }
    return (p[0], p[1], p[2])
}

/// "2026-10-15" → "Oct 15, 2026"
func formatDate(_ iso: String) -> String {
    let (y, m, d) = parts(iso)
    return "\(months[m - 1]) \(d), \(y)"
}

private func dayNumber(_ iso: String) -> Int {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let (y, m, d) = parts(iso)
    let date = cal.date(from: DateComponents(year: y, month: m, day: d))!
    return Int((date.timeIntervalSince1970 / 86_400).rounded())
}

private func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }

/// "in 3 months", "5 days ago", "today".
func relativeDays(_ iso: String, today: String) -> String {
    let diff = dayNumber(iso) - dayNumber(today)
    let n = abs(diff)
    if n == 0 { return "today" }
    if n == 1 { return diff > 0 ? "tomorrow" : "yesterday" }
    let span: String
    switch n {
    case ..<14: span = plural(n, "day")
    case ..<60: span = plural(Int((Double(n) / 7).rounded()), "week")
    case ..<365: span = plural(Int((Double(n) / 30).rounded()), "month")
    default: span = plural(Int((Double(n) / 365).rounded()), "year")
    }
    return diff > 0 ? "in \(span)" : "\(span) ago"
}
