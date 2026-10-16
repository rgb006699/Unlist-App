import Foundation

/// One broker joined with the owner's record for it (shared/merge.ts).
struct BrokerRow: Identifiable, Equatable, Sendable {
    let broker: Broker
    let record: BrokerRecord?
    let view: ViewStatus
    let nextDate: String?

    var id: String { broker.id }
}

private func nextDate(_ record: BrokerRecord?) -> String? {
    switch record?.status {
    case .removed: record?.recheckAt
    case .requestSent: record?.requestSentAt
    default: nil
    }
}

/// Records whose broker is no longer in the list are left alone, not shown.
func mergeBrokers(_ brokers: [Broker], _ records: [String: BrokerRecord], today: String) -> [BrokerRow] {
    brokers.map { broker in
        let record = records[broker.id]
        return BrokerRow(broker: broker, record: record, view: viewStatus(record, today: today), nextDate: nextDate(record))
    }
}
