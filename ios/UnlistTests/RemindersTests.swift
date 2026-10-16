import Foundation
import Testing
@testable import Unlist

@Suite struct RemindersTests {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func rows(_ records: [String: BrokerRecord], today: String = Fixtures.today) -> [BrokerRow] {
        mergeBrokers(Fixtures.brokers, records, today: today)
    }

    @Test func removedBrokerWithFutureRecheckGetsOneReminder() {
        let rec = applyStatus(nil, .removed, today: "2026-10-15", recheckDays: 90) // recheck 2027-01-13
        let list = reminders(for: rows(["spokeo": rec]), now: at(2026, 10, 15, 12), calendar: cal)
        #expect(list == [Reminder(
            id: "recheck-spokeo", brokerId: "spokeo",
            title: "Time to recheck Spokeo",
            body: "Search again to make sure your listing hasn't come back.",
            fireDate: DateComponents(year: 2027, month: 1, day: 13, hour: 9, minute: 0))])
    }

    @Test func recheckTodayIsScheduledOnlyBeforeNine() {
        let rec = applyStatus(nil, .removed, today: "2026-07-17", recheckDays: 90) // recheck 2026-10-15
        let row = mergeBrokers([Fixtures.brokers[0]], ["spokeo": rec], today: "2026-10-14")
        #expect(reminders(for: row, now: at(2026, 10, 15, 8), calendar: cal).count == 1)
        #expect(reminders(for: row, now: at(2026, 10, 15, 10), calendar: cal).isEmpty)
    }

    @Test func otherStatusesGetNoReminder() {
        // Fixtures: whitepages found, acxiom request sent, radaris due, spokeo not checked.
        var recs = Fixtures.records
        recs["mylife"] = applyStatus(nil, .relisted, today: Fixtures.today, recheckDays: 90)
        #expect(reminders(for: rows(recs), now: at(2026, 10, 15, 12), calendar: cal).isEmpty)
    }
}
