import Foundation
import Testing
@testable import Unlist

private let T = "2026-10-15"

@Suite struct DatesTests {
    @Test func todayUsesLocalDateLateAtNight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let lateNight = cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 23, minute: 30))!
        #expect(todayISO(lateNight, calendar: cal) == "2026-10-15")
    }

    @Test func todayPadsMonthAndDay() {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        #expect(todayISO(d, calendar: cal) == "2026-01-05")
    }

    @Test func addDaysCrossesYearAndMonthEnds() {
        #expect(addDays("2026-10-15", 90) == "2027-01-13")
        #expect(addDays("2026-02-28", 1) == "2026-03-01")
    }
}

@Suite struct ApplyStatusTests {
    @Test func createsRecordFromNothing() {
        #expect(applyStatus(nil, .found, today: T, recheckDays: 90) == BrokerRecord(
            status: .found, listingUrl: "", notes: "", requestSentAt: nil, removedAt: nil, recheckAt: nil,
            history: [HistoryEntry(at: T, status: .status(.found))]))
    }

    @Test func requestSentSetsDate() {
        let rec = applyStatus(applyStatus(nil, .found, today: "2026-10-01", recheckDays: 90), .requestSent, today: T, recheckDays: 90)
        #expect(rec.requestSentAt == T)
    }

    @Test func removedSetsRemovedAndRecheck() {
        let rec = applyStatus(nil, .removed, today: T, recheckDays: 90)
        #expect(rec.removedAt == T)
        #expect(rec.recheckAt == "2027-01-13")
    }

    @Test func relistedClearsRecheckKeepsRemoved() {
        let rec = applyStatus(applyStatus(nil, .removed, today: T, recheckDays: 90), .relisted, today: "2026-12-01", recheckDays: 90)
        #expect(rec.recheckAt == nil)
        #expect(rec.removedAt == T)
    }

    @Test func leavingRemovedClearsRecheck() {
        let removed = applyStatus(nil, .removed, today: T, recheckDays: 90)
        #expect(applyStatus(removed, .found, today: T, recheckDays: 90).recheckAt == nil)
        #expect(applyStatus(removed, .requestSent, today: T, recheckDays: 90).recheckAt == nil)
    }

    @Test func appendsOneHistoryEntry() {
        let a = applyStatus(nil, .found, today: T, recheckDays: 90)
        let b = applyStatus(a, .requestSent, today: T, recheckDays: 90)
        #expect(a.history.count == 1)
        #expect(b.history == [HistoryEntry(at: T, status: .status(.found)), HistoryEntry(at: T, status: .status(.requestSent))])
    }
}

@Test func markStillRemovedRestartsClock() {
    let rec = applyStatus(nil, .removed, today: T, recheckDays: 90)
    let next = markStillRemoved(rec, today: "2027-01-13", recheckDays: 90)
    #expect(next.status == .removed)
    #expect(next.removedAt == T)
    #expect(next.recheckAt == "2027-04-13")
    #expect(next.history.last == HistoryEntry(at: "2027-01-13", status: .rechecked))
}

@Suite struct ViewStatusTests {
    let removed = applyStatus(nil, .removed, today: T, recheckDays: 90)

    @Test func noRecordIsNotChecked() { #expect(viewStatus(nil, today: T) == .notChecked) }

    @Test func dueOnAndAfterRecheck() {
        #expect(viewStatus(removed, today: "2027-01-13") == .due)
        #expect(viewStatus(removed, today: "2027-02-01") == .due)
        #expect(viewStatus(removed, today: "2027-01-12") == .removed)
    }

    @Test func otherStatusesPassThrough() {
        #expect(viewStatus(applyStatus(nil, .relisted, today: T, recheckDays: 90), today: T) == .relisted)
    }
}

@Test func progressCounts() {
    #expect(progress([.removed, .due, .found, .requestSent, .relisted, .notChecked])
        == Progress(total: 6, removed: 1, pending: 3, due: 1, notChecked: 1))
}
