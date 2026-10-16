import Foundation
import Testing
@testable import Unlist

@Suite struct BrokerFieldsTests {
    private func json(_ extra: String) -> Data {
        Data(#"[{"id":"x","name":"X","searchUrl":"https://x.com","optOutUrl":"https://x.com/o","method":"web_form","optOutEmail":null,"needsCaptcha":false,"needsEmailConfirm":false,"needsId":false,"relistRisk":"low","steps":["a"],"lastVerified":""\#(extra)}]"#.utf8)
    }

    @Test func decodesAllNewFields() throws {
        let list = BrokerList.load(from: json(##","searchTemplate":"https://x.com/s?n={first}%20{last:slug}","group":"people-connect","autofill":{"email":"#mail","zip":"input[name=z]"}"##))
        let b = try #require(list.first)
        #expect(b.searchTemplate == "https://x.com/s?n={first}%20{last:slug}")
        #expect(b.group == "people-connect")
        #expect(b.autofill == [.email: "#mail", .zip: "input[name=z]"])
    }

    @Test func newFieldsAreOptional() throws {
        let b = try #require(BrokerList.load(from: json("")).first)
        #expect(b.searchTemplate == nil && b.group == nil && b.autofill == nil)
    }

    @Test func unknownAutofillKeysAreDropped() throws {
        let b = try #require(BrokerList.load(from: json(##","autofill":{"email":"#e","favoriteColor":"#c"}"##)).first)
        #expect(b.autofill == [.email: "#e"])
    }

    @Test(arguments: [
        #""http://x.com/{first}""#,
        #""https://x.com/{nickname}""#,
        #""https://x.com/{first:upper}""#,
        #""https://x.com/{first""#,
    ])
    func badTemplatesAreDroppedButBrokerKept(_ template: String) throws {
        var log: [String] = []
        let list = BrokerList.load(from: json(#","searchTemplate":\#(template)"#)) { log.append($0) }
        let b = try #require(list.first)
        #expect(b.searchTemplate == nil)
        #expect(log.contains { $0.hasPrefix("Dropping searchTemplate for x") })
    }

    @Test func badGroupIsDroppedButBrokerKept() throws {
        var log: [String] = []
        let b = try #require(BrokerList.load(from: json(#","group":"People Connect""#)) { log.append($0) }.first)
        #expect(b.group == nil)
        #expect(log.contains { $0.hasPrefix("Dropping group for x") })
    }

    @Test func placeholdersAreParsed() {
        let p = templatePlaceholders("https://a/{first}-{last:Slug}?c={city:slug}")
        #expect(p.map(\.name) == ["first", "last", "city"])
        #expect(p.map(\.modifier) == [nil, "Slug", "slug"])
    }
}
