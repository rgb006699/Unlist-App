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
            fireDate: DateComponents(calendar: cal, year: 2027, month: 1, day: 13, hour: 9, minute: 0))])
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

@Suite struct ReminderCalendarTests {
    @Test func buddhistDeviceCalendarStillSchedulesTheGregorianDate() throws {
        var cal = Calendar(identifier: .buddhist)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = cal.timeZone
        let now = greg.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))!
        let rec = applyStatus(nil, .removed, today: "2026-10-15", recheckDays: 90)
        let row = mergeBrokers([Fixtures.brokers[0]], ["spokeo": rec], today: "2026-10-15")
        let list = reminders(for: row, now: now, calendar: cal)
        let fire = try #require(list.first?.fireDate)
        #expect(fire.year == 2027 && fire.month == 1 && fire.day == 13 && fire.hour == 9)
        #expect(fire.calendar?.identifier == .gregorian)
    }
}
