import Foundation
import Testing
@testable import Unlist

@Suite struct DatesLabelsTests {
    let T = Fixtures.today

    @Test func formatsShortMonthDayYear() {
        #expect(formatDate("2026-10-15") == "Oct 15, 2026")
        #expect(formatDate("2027-01-03") == "Jan 3, 2027")
    }

    @Test(arguments: [
        ("2026-10-15", "today"),
        ("2026-10-16", "tomorrow"),
        ("2026-10-14", "yesterday"),
        ("2026-10-20", "in 5 days"),
        ("2026-10-10", "5 days ago"),
        ("2026-11-05", "in 3 weeks"),
        ("2027-01-13", "in 3 months"),
        ("2026-06-10", "4 months ago"),
        ("2028-01-01", "in 1 year"),
    ])
    func relative(_ iso: String, _ expected: String) {
        #expect(relativeDays(iso, today: T) == expected)
    }

    private func row(_ rec: BrokerRecord?) -> BrokerRow {
        mergeBrokers([Fixtures.brokers[0]], rec.map { ["spokeo": $0] } ?? [:], today: T)[0]
    }

    @Test func nextStepForEachStatus() {
        #expect(nextStep(row(nil)) == "Search for your listing")
        #expect(nextStep(row(applyStatus(nil, .found, today: T, recheckDays: 90))) == "Send a removal request")
        #expect(nextStep(row(applyStatus(nil, .requestSent, today: "2026-10-10", recheckDays: 90))) == "Waiting since Oct 10, 2026")
        #expect(nextStep(row(applyStatus(nil, .removed, today: T, recheckDays: 90))) == "Recheck Jan 13, 2027")
        #expect(nextStep(row(applyStatus(nil, .relisted, today: T, recheckDays: 90))) == "Send a new request")
        #expect(nextStep(row(applyStatus(nil, .removed, today: "2026-06-01", recheckDays: 90))) == "Search again now")
    }

    @Test func everyStatusHasLabelHelpAndSymbol() {
        for s in ViewStatus.allCases {
            #expect(!s.label.isEmpty)
            #expect(s.help.count > 10)
            #expect(!s.symbol.isEmpty)
        }
        #expect(ViewStatus.removed.label == "Confirmed removed")
        #expect(RemovalMethod.idUpload.label == "ID upload")
    }
}
