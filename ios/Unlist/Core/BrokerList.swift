import Foundation

/// The broker list bundled with the app (the repo's root brokers.json).
enum BrokerList {
    /// Decodes each entry on its own so one bad entry doesn't drop the list.
    private struct Entry: Decodable {
        let id: String?
        let broker: Result<Broker, Error>

        private enum Keys: String, CodingKey { case id }

        init(from decoder: Decoder) throws {
            id = try? decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .id)
            broker = Result { try Broker(from: decoder) }
        }
    }

    static func load(from data: Data, log: (String) -> Void = { _ in }) -> [Broker] {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            log("brokers.json is not a JSON array of brokers")
            return []
        }
        var seen = Set<String>()
        var brokers: [Broker] = []
        for (index, entry) in entries.enumerated() {
            let label = entry.id ?? "#\(index)"
            switch entry.broker {
            case .failure(let error):
                log("Skipping broker \(label): \(error.localizedDescription)")
            case .success(let broker) where !broker.lastVerified.isEmpty && !isISODate(broker.lastVerified):
                log("Skipping broker \(label): lastVerified must be YYYY-MM-DD or empty")
            case .success(let broker) where broker.method == .email && broker.optOutEmail == nil:
                log("Skipping broker \(label): optOutEmail is required when method is email")
            case .success(let broker) where seen.contains(broker.id):
                log("Skipping broker \(label): duplicate id")
            case .success(var broker):
                if let template = broker.searchTemplate, let problem = templateProblem(template) {
                    log("Dropping searchTemplate for \(broker.id): \(problem)")
                    broker.searchTemplate = nil
                }
                if let group = broker.group, group.range(of: "^[a-z0-9-]+$", options: .regularExpression) == nil {
                    log("Dropping group for \(broker.id): must be a lowercase slug")
                    broker.group = nil
                }
                seen.insert(broker.id)
                brokers.append(broker)
            }
        }
        return brokers
    }

    static func bundled() -> [Broker] {
        guard let url = Bundle.main.url(forResource: "brokers", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return load(from: data) { message in
            #if DEBUG
            print(message)
            #endif
        }
    }
}
