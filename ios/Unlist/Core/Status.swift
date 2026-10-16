import Foundation

// Status rules — a port of the web app's shared/status.ts. Dates are local
// calendar dates as "YYYY-MM-DD" strings.

private func iso(_ c: DateComponents) -> String {
    String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

private func components(_ iso: String) -> DateComponents {
    let p = iso.split(separator: "-").compactMap { Int($0) }
    return DateComponents(year: p[0], month: p[1], day: p[2])
}

/// A Gregorian calendar in the given calendar's time zone. Dates are always
/// stored as Gregorian YYYY-MM-DD, whatever calendar the iPhone is set to.
func gregorian(like calendar: Calendar = .current) -> Calendar {
    var g = Calendar(identifier: .gregorian)
    g.timeZone = calendar.timeZone
    return g
}

/// Today's local date. Never derived from UTC.
func todayISO(_ now: Date = .now, calendar: Calendar = .current) -> String {
    iso(gregorian(like: calendar).dateComponents([.year, .month, .day], from: now))
}

/// True for a real calendar date written as YYYY-MM-DD.
func isISODate(_ s: String) -> Bool {
    let p = s.split(separator: "-", omittingEmptySubsequences: false)
    guard s.count == 10, p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
          let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]), (1...12).contains(m), d >= 1 else { return false }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
    let back = cal.dateComponents([.year, .month, .day], from: date)
    return back.year == y && back.month == m && back.day == d
}

func addDays(_ date: String, _ days: Int) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let start = cal.date(from: components(date))!
    let end = cal.date(byAdding: .day, value: days, to: start)!
    return iso(cal.dateComponents([.year, .month, .day], from: end))
}

func applyStatus(_ rec: BrokerRecord?, _ status: Status, today: String, recheckDays: Int) -> BrokerRecord {
    var next = rec ?? BrokerRecord(status: status, listingUrl: "", notes: "", requestSentAt: nil, removedAt: nil, recheckAt: nil, history: [])
    next.status = status
    next.history.append(HistoryEntry(at: today, status: .status(status)))
    if status == .requestSent { next.requestSentAt = today }
    if status == .removed {
        next.removedAt = today
        next.recheckAt = addDays(today, recheckDays)
    } else {
        next.recheckAt = nil
    }
    return next
}

func markStillRemoved(_ rec: BrokerRecord, today: String, recheckDays: Int) -> BrokerRecord {
    var next = rec
    next.recheckAt = addDays(today, recheckDays)
    next.history.append(HistoryEntry(at: today, status: .rechecked))
    return next
}

func viewStatus(_ rec: BrokerRecord?, today: String) -> ViewStatus {
    guard let rec else { return .notChecked }
    if rec.status == .removed, let recheck = rec.recheckAt, recheck <= today { return .due }
    switch rec.status {
    case .found: return .found
    case .requestSent: return .requestSent
    case .removed: return .removed
    case .relisted: return .relisted
    }
}

func progress(_ statuses: [ViewStatus]) -> Progress {
    func count(_ s: ViewStatus...) -> Int { statuses.filter { s.contains($0) }.count }
    return Progress(
        total: statuses.count,
        removed: count(.removed),
        pending: count(.found, .requestSent, .relisted),
        due: count(.due),
        notChecked: count(.notChecked)
    )
}
