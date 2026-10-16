import Foundation
import Testing
@testable import Unlist

@Suite struct FilterTests {
    let rows = mergeBrokers(Fixtures.brokers, Fixtures.records, today: Fixtures.today)

    @Test func noFilterShowsEverything() {
        #expect(filterRows(rows, group: nil, query: "").count == 5)
    }

    @Test func tileGroupsMatchTheirStatuses() {
        #expect(filterRows(rows, group: .removed, query: "").map(\.id) == ["mylife"])
        #expect(filterRows(rows, group: .inProgress, query: "").map(\.id) == ["whitepages", "acxiom"])
        #expect(filterRows(rows, group: .due, query: "").map(\.id) == ["radaris"])
        #expect(filterRows(rows, group: .notChecked, query: "").map(\.id) == ["spokeo"])
    }

    @Test func searchIsCaseInsensitiveAndTrimmed() {
        #expect(filterRows(rows, group: nil, query: " spo ").map(\.id) == ["spokeo"])
        #expect(filterRows(rows, group: .removed, query: "spo").isEmpty)
    }

    @Test func tileCountsMatchProgress() {
        let p = progress(rows.map(\.view))
        #expect(TileGroup.allCases.map { $0.count(in: p) } == [1, 2, 1, 1])
        #expect(TileGroup.allCases.map(\.label) == ["Removed", "In progress", "Need recheck", "Not checked yet"])
    }
}
