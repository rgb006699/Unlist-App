import SwiftUI
import UIKit

/// One-tap copy chips for the owner's details, for forms Fill can't handle.
struct DetailsBar: View {
    let profile: Profile
    @State private var copied: String?

    private struct Item: Identifiable {
        let kind: String
        let value: String
        var id: String { kind + "|" + value }
    }

    private var items: [Item] {
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        var out: [Item] = []
        if !clean(profile.fullName).isEmpty { out.append(Item(kind: "Name", value: clean(profile.fullName))) }
        out += profile.aliases.map(clean).filter { !$0.isEmpty }.map { Item(kind: "Other name", value: $0) }
        out += profile.addresses.map(oneLine).filter { !$0.isEmpty }.map { Item(kind: "Address", value: $0) }
        out += profile.phones.map(clean).filter { !$0.isEmpty }.map { Item(kind: "Phone", value: $0) }
        out += profile.emails.map(clean).filter { !$0.isEmpty }.map { Item(kind: "Email", value: $0) }
        return out
    }

    private func oneLine(_ a: Address) -> String {
        let stateZip = [a.state, a.zip].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return [a.street, a.city, stateZip].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        UIPasteboard.general.string = item.value
                        copied = item.id
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            if copied == item.id { copied = nil }
                        }
                    } label: {
                        Label(item.value, systemImage: copied == item.id ? "checkmark" : "doc.on.doc")
                            .labelStyle(CompactLabelStyle(spacing: 5))
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                            .frame(maxWidth: 220)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(copied == item.id ? "Copied \(item.kind)" : "Copy \(item.kind): \(item.value)")
                }
            }
            .padding(.horizontal)
        }
    }
}
