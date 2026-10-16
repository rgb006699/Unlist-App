import Foundation
import Testing
@testable import Unlist

@Suite struct BundledBrokerFieldsTests {
    let brokers = BrokerList.bundled()

    @Test func everyBundledTemplateBuildsADirectLink() {
        let withTemplate = brokers.filter { $0.searchTemplate != nil }
        #expect(withTemplate.count >= 6)
        for b in withTemplate {
            guard case .direct(let url) = searchLink(for: b, profile: Fixtures.profile) else {
                Issue.record("\(b.id) didn't build a direct link")
                continue
            }
            #expect(url.scheme == "https", "\(b.id)")
            #expect(url.absoluteString.lowercased().contains("doe"), "\(b.id)")
        }
    }

    @Test func peopleConnectBrokersShareAGroup() {
        let members = brokers.filter { $0.group == "peopleconnect" }.map(\.id).sorted()
        #expect(members == ["instantcheckmate", "intelius", "truthfinder", "ussearch", "zabasearch"])
    }
}
