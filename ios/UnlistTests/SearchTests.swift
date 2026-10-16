import Foundation
import Testing
@testable import Unlist

@Suite struct SearchTests {
    private func broker(_ template: String?) -> Broker {
        var b = Fixtures.broker("site", "Site")
        b.searchTemplate = template
        return b
    }

    private func profile(_ name: String, city: String = "Austin", state: String = "TX", zip: String = "78701",
                         addresses: [Address]? = nil) -> Profile {
        Profile(fullName: name, aliases: [],
                addresses: addresses ?? [Address(street: "1 Main", city: city, state: state, zip: zip, current: true)],
                phones: [], emails: [])
    }

    private func url(_ template: String, _ p: Profile) -> String? {
        if case .direct(let u) = searchLink(for: broker(template), profile: p) { return u.absoluteString }
        return nil
    }

    @Test func plainPlaceholdersArePercentEncoded() {
        #expect(url("https://a.com/s?n={first}%20{last}", profile("Jane Q Doe")) == "https://a.com/s?n=Jane%20Doe")
        #expect(url("https://a.com/s?m={middle}", profile("Jane Q Doe")) == "https://a.com/s?m=Q")
    }

    @Test func slugFormsHandlePunctuation() {
        #expect(url("https://a.com/{first:slug}-{last:slug}", profile("Mary-Kate O'Brien")) == "https://a.com/mary-kate-obrien")
        #expect(url("https://a.com/{last:Slug}", profile("Mary-Kate O'Brien")) == "https://a.com/OBrien")
        #expect(url("https://a.com/{first:Slug}", profile("Mary-Kate O'Brien")) == "https://a.com/Mary-Kate")
    }

    @Test func accentsAreFoldedInSlugsAndEncodedOtherwise() {
        #expect(url("https://a.com/{first:slug}", profile("José Núñez")) == "https://a.com/jose")
        #expect(url("https://a.com/?l={last}", profile("José Núñez")) == "https://a.com/?l=N%C3%BA%C3%B1ez")
    }

    @Test func extraSpacesAreIgnored() {
        #expect(url("https://a.com/{first}/{last}", profile("  Jane    Doe ")) == "https://a.com/Jane/Doe")
    }

    @Test func cityAndStateForms() {
        let p = profile("Jane Doe", city: "San Antonio")
        #expect(url("https://a.com/{city:slug}-{state:slug}", p) == "https://a.com/san-antonio-tx")
        #expect(url("https://a.com/?c={city}", p) == "https://a.com/?c=San%20Antonio")
        #expect(url("https://a.com/{stateName:Slug}/{city:Slug}", p) == "https://a.com/Texas/San-Antonio")
    }

    @Test func oneWordNameFallsBack() {
        let link = searchLink(for: broker("https://a.com/{first}-{last}"), profile: profile("Cher"))
        #expect(link == .fallback(URL(string: "https://site.example/search")!, missing: ["last name"]))
    }

    @Test func missingAddressFallsBackNamingTheFields() {
        let link = searchLink(for: broker("https://a.com/{first}/{city}/{state}"), profile: profile("Jane Doe", addresses: []))
        #expect(link == .fallback(URL(string: "https://site.example/search")!, missing: ["city", "state"]))
    }

    @Test func currentAddressIsPreferredElseFirst() {
        let two = [Address(street: "", city: "Dallas", state: "TX", zip: "", current: false),
                   Address(street: "", city: "Austin", state: "TX", zip: "", current: true)]
        #expect(url("https://a.com/{city}", profile("Jane Doe", addresses: two)) == "https://a.com/Austin")
        let none = two.map { var a = $0; a.current = false; return a }
        #expect(url("https://a.com/{city}", profile("Jane Doe", addresses: none)) == "https://a.com/Dallas")
    }

    @Test func noTemplateUsesTheSearchPage() {
        #expect(searchLink(for: broker(nil), profile: profile("Jane Doe"))
            == .fallback(URL(string: "https://site.example/search")!, missing: []))
    }

    @Test func nameSuffixesAndTitlesAreIgnored() {
        #expect(url("https://a.com/{first}-{last}", profile("John Smith Jr.")) == "https://a.com/John-Smith")
        #expect(url("https://a.com/{first}-{last}", profile("John Smith, III")) == "https://a.com/John-Smith")
        #expect(url("https://a.com/{first}-{last}", profile("Dr. Jane Doe Sr")) == "https://a.com/Jane-Doe")
        #expect(SearchValues(profile: profile("Mary Ann Smith II")).middle == "Ann")
    }

    @Test func emptySlugCountsAsMissing() {
        let link = searchLink(for: broker("https://a.com/{first:slug}-{last:slug}"), profile: profile("太郎 Smith"))
        #expect(link == .fallback(URL(string: "https://site.example/search")!, missing: ["first name"]))
    }

    @Test func fullStateNamesAreUnderstood() {
        let v = SearchValues(profile: profile("Jane Doe", state: "Texas"))
        #expect(v.state == "TX")
        #expect(v.stateName == "Texas")
        #expect(SearchValues(profile: profile("Jane Doe", state: " new york ")).state == "NY")
        #expect(autofillValues(profile("Jane Doe", state: "Texas"))[.state] == "TX")
    }

    @Test func stateNamesCoverEveryState() {
        #expect(stateNames.count == 51)
        #expect(stateNames["TX"] == "Texas")
        #expect(SearchValues(profile: profile("Jane Doe", state: "tx")).stateName == "Texas")
    }
}
