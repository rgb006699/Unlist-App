import Foundation
import Testing

@Test func bundleHasBrokers() {
    #expect(Bundle.main.url(forResource: "brokers", withExtension: "json") != nil)
}
