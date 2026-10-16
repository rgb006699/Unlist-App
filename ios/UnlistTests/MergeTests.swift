import Foundation
import Testing
@testable import Unlist

@Suite struct MergeTests {
    let T = Fixtures.today

    @Test func keepsOrderAndMarksMissingRecordsNotChecked() {
        let rows = mergeBrokers(Fixtures.brokers, Fixtures.records, today: T)
        #expect(rows.map(\.broker.id) == ["spokeo", "whitepages", "acxiom", "mylife", "radaris"])
        #expect(rows[0].record == nil)
        #expect(rows[0].view == .notChecked)
        #expect(rows[0].nextDate == nil)
    }

    @Test func nextDateFollowsStatus() {
        let rows = mergeBrokers(Fixtures.brokers, Fixtures.records, today: T)
        #expect(rows[1].nextDate == nil)
        #expect(rows[2].nextDate == "2026-10-05")
        #expect(rows[3].nextDate == "2026-12-30")
        #expect(rows[4].view == .due)
        #expect(rows[4].nextDate == "2026-08-30")
    }

    @Test func orphanRecordsProduceNoRow() {
        var recs = Fixtures.records
        recs["retired"] = applyStatus(nil, .found, today: T, recheckDays: 90)
        let rows = mergeBrokers(Fixtures.brokers, recs, today: T)
        #expect(rows.count == 5)
        #expect(!rows.contains { $0.broker.id == "retired" })
    }

    @Test func progressOverRows() {
        let rows = mergeBrokers(Fixtures.brokers, Fixtures.records, today: T)
        #expect(progress(rows.map(\.view)) == Progress(total: 5, removed: 1, pending: 2, due: 1, notChecked: 1))
    }
}

@Suite struct BrokerListTests {
    @Test func skipsInvalidAndDuplicateEntriesAndLogsThem() throws {
        let json = #"""
        [
          {"id":"alpha","name":"Alpha","searchUrl":"https://a.com","optOutUrl":"https://a.com/o","method":"web_form","optOutEmail":null,"needsCaptcha":false,"needsEmailConfirm":false,"needsId":false,"relistRisk":"low","steps":["x"],"lastVerified":""},
          {"id":"bad","name":"Bad","searchUrl":"https://b.com","optOutUrl":"https://b.com/o","method":"fax","optOutEmail":null,"needsCaptcha":false,"needsEmailConfirm":false,"needsId":false,"relistRisk":"low","steps":["x"],"lastVerified":""},
          {"id":"noemail","name":"No Email","searchUrl":"https://c.com","optOutUrl":"https://c.com/o","method":"email","optOutEmail":null,"needsCaptcha":false,"needsEmailConfirm":false,"needsId":false,"relistRisk":"low","steps":["x"],"lastVerified":""},
          {"id":"alpha","name":"Alpha again","searchUrl":"https://a.com","optOutUrl":"https://a.com/o","method":"web_form","optOutEmail":null,"needsCaptcha":false,"needsEmailConfirm":false,"needsId":false,"relistRisk":"low","steps":["x"],"lastVerified":""}
        ]
        """#
        var log: [String] = []
        let list = BrokerList.load(from: Data(json.utf8)) { log.append($0) }
        #expect(list.map(\.id) == ["alpha"])
        #expect(log.count == 3)
        #expect(log.last?.hasPrefix("Skipping broker alpha: duplicate id") == true)
    }

    @Test func bundledListHasEnoughValidBrokers() {
        let list = BrokerList.bundled()
        #expect(list.count >= 35)
        #expect(Set(list.map(\.id)).count == list.count)
        #expect(list.allSatisfy { $0.searchUrl.hasPrefix("https://") && $0.optOutUrl.hasPrefix("https://") && !$0.steps.isEmpty })
    }
}
