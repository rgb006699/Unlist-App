import Foundation
import Testing
@testable import Unlist

private let webJSON = #"""
{"version":1,"profile":{"fullName":"Jane","aliases":[],"addresses":[{"street":"1 Main","city":"Austin","state":"TX","zip":"78701","current":true}],"phones":[],"emails":[]},"settings":{"recheckDays":90},"records":{"spokeo":{"status":"removed","listingUrl":"","notes":"","requestSentAt":null,"removedAt":"2026-10-01","recheckAt":"2026-12-30","history":[{"at":"2026-10-01","status":"removed"},{"at":"2026-12-30","status":"rechecked"}]}}}
"""#

@Suite struct ModelsTests {
    @Test func decodesAWebDataFileAndRoundTrips() throws {
        let data = try JSONDecoder().decode(DataFile.self, from: Data(webJSON.utf8))
        #expect(data.profile.fullName == "Jane")
        #expect(data.records["spokeo"]?.history.last?.status == .rechecked)
        #expect(data.records["spokeo"]?.requestSentAt == nil)
        let again = try JSONDecoder().decode(DataFile.self, from: JSONEncoder().encode(data))
        #expect(again == data)
    }

    @Test func nilDatesEncodeAsNull() throws {
        let rec = applyStatus(nil, .found, today: "2026-10-15", recheckDays: 90)
        let json = String(decoding: try JSONEncoder().encode(rec), as: UTF8.self)
        #expect(json.contains(#""requestSentAt":null"#))
        #expect(json.contains(#""recheckAt":null"#))
    }

    @Test func emptyDataFileHasDefaults() {
        let d = DataFile.empty()
        #expect(d.version == 1)
        #expect(d.settings.recheckDays == 90)
        #expect(d.records.isEmpty)
    }
}
