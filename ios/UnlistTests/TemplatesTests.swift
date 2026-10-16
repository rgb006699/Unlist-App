import Foundation
import Testing
@testable import Unlist

private let broker = Broker(id: "spokeo", name: "Spokeo", searchUrl: "https://www.spokeo.com",
                            optOutUrl: "https://www.spokeo.com/optout", method: .email, optOutEmail: "privacy@spokeo.com",
                            needsCaptcha: false, needsEmailConfirm: true, needsId: false, relistRisk: .high,
                            steps: ["Search"], lastVerified: "2026-10-15")

@Suite struct TdpsaTemplateTests {
    let filled = fillTemplate(.tdpsa, profile: Fixtures.profile, broker: broker, listingUrl: "https://www.spokeo.com/Jane-Doe/123")

    @Test func subject() {
        #expect(filled.subject == "Request to delete my personal data — Texas Data Privacy and Security Act")
    }

    @Test func citesTheActAndNamesTheBroker() {
        #expect(filled.body.contains("Texas Data Privacy and Security Act"))
        #expect(filled.body.contains("Spokeo"))
    }

    @Test func includesEveryIdentifyingDetail() {
        for s in ["Jane Q Doe", "Jane Doe", "J. Smith", "512-555-0100", "jane@example.com",
                  "22 New St, Austin, TX 78701", "1 Old Rd, Dallas, TX 75201"] {
            #expect(filled.body.contains(s), "missing \(s)")
        }
    }

    @Test func currentAddressComesBeforePreviousOnes() throws {
        let body = filled.body
        let cur = try #require(body.range(of: "Current address"))
        let prev = try #require(body.range(of: "Previous addresses"))
        #expect(cur.lowerBound < prev.lowerBound)
        #expect(body.range(of: "22 New St")!.lowerBound < prev.lowerBound)
        #expect(body.range(of: "1 Old Rd")!.lowerBound > prev.lowerBound)
    }

    @Test func includesTheListingUrl() {
        #expect(filled.body.contains("https://www.spokeo.com/Jane-Doe/123"))
    }
}

@Suite struct GeneralTemplateTests {
    let filled = fillTemplate(.general, profile: Fixtures.profile, broker: broker, listingUrl: "")

    @Test func subject() { #expect(filled.subject == "Request to remove my personal information") }

    @Test func hasNoLegalCitation() {
        #expect(!filled.body.contains("Texas"))
        #expect(!filled.body.contains("Act"))
    }

    @Test func stillHasIdentifyingDetails() {
        #expect(filled.body.contains("Jane Q Doe"))
        #expect(filled.body.contains("512-555-0100"))
    }

    @Test func omitsListingLineWithoutUrl() {
        #expect(filled.body.range(of: "listing", options: .caseInsensitive) == nil)
    }
}

@Suite struct SparseProfileTests {
    @Test(arguments: TemplateID.allCases)
    func emptyProfilePrintsNoBlanks(_ id: TemplateID) {
        let body = fillTemplate(id, profile: .empty, broker: broker, listingUrl: "").body
        #expect(!body.contains("undefined"))
        #expect(!body.contains("\n\n\n"))
        #expect(!body.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces).hasSuffix(":") })
    }

    @Test func noCurrentAddressUsesOneAddressesLine() {
        var p = Fixtures.profile
        p.addresses = p.addresses.map { var a = $0; a.current = false; return a }
        let body = fillTemplate(.general, profile: p, broker: broker, listingUrl: "").body
        #expect(body.contains("Addresses"))
        #expect(!body.contains("Current address"))
        #expect(!body.contains("Previous addresses"))
        #expect(body.contains("22 New St, Austin, TX 78701"))
    }
}

@Suite struct MailtoTests {
    @Test func specialCharactersRoundTrip() throws {
        let url = mailtoURL(to: "privacy@x.com", subject: "Hi & bye", body: "Line 1\nO'Brien #2")
        #expect(url.absoluteString.hasPrefix("mailto:privacy@x.com?subject="))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "subject" }?.value == "Hi & bye")
        #expect(items.first { $0.name == "body" }?.value == "Line 1\nO'Brien #2")
    }

    @Test func noRecipient() {
        #expect(mailtoURL(to: nil, subject: "s", body: "b").absoluteString.hasPrefix("mailto:?subject="))
    }
}
