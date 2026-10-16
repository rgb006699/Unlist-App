import Foundation
@testable import Unlist

// Same fixture as the web tests (web/test/fixtures.ts).
enum Fixtures {
    static let today = "2026-10-15"

    static func broker(_ id: String, _ name: String, _ method: RemovalMethod = .webForm,
                       captcha: Bool = false, confirm: Bool = false, needsId: Bool = false) -> Broker {
        Broker(id: id, name: name, searchUrl: "https://\(id).example/search", optOutUrl: "https://\(id).example/optout",
               method: method, optOutEmail: method == .email ? "privacy@\(id).example" : nil,
               needsCaptcha: captcha, needsEmailConfirm: confirm, needsId: needsId, relistRisk: .medium,
               steps: ["Search for your name", "Submit the form"], lastVerified: today)
    }

    static let brokers: [Broker] = [
        broker("spokeo", "Spokeo", captcha: true, confirm: true),
        broker("whitepages", "Whitepages", .phone),
        broker("acxiom", "Acxiom", .email),
        broker("mylife", "MyLife", .idUpload, needsId: true),
        broker("radaris", "Radaris"),
    ]

    static let records: [String: BrokerRecord] = [
        "whitepages": applyStatus(nil, .found, today: "2026-10-10", recheckDays: 90),
        "acxiom": applyStatus(applyStatus(nil, .found, today: "2026-10-01", recheckDays: 90), .requestSent, today: "2026-10-05", recheckDays: 90),
        "mylife": applyStatus(nil, .removed, today: "2026-10-01", recheckDays: 90),
        "radaris": applyStatus(nil, .removed, today: "2026-06-01", recheckDays: 90), // due
    ]

    static var profile: Profile {
        Profile(fullName: "Jane Q Doe", aliases: ["Jane Doe", "J. Smith"],
                addresses: [Address(street: "1 Old Rd", city: "Dallas", state: "TX", zip: "75201", current: false),
                            Address(street: "22 New St", city: "Austin", state: "TX", zip: "78701", current: true)],
                phones: ["512-555-0100"], emails: ["jane@example.com"])
    }
}
