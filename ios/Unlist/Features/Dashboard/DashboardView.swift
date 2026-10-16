import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var group: TileGroup?
    @State private var query = ""

    var body: some View {
        let rows = model.rows
        let counts = progress(rows.map(\.view))
        let due = rows.filter { $0.view == .due }
        let visible = filterRows(rows, group: group, query: query)

        List {
            Section {
                SummaryView(counts: counts, group: $group)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            if counts.total > 0, counts.notChecked == counts.total {
                Section("How Unlist works") {
                    HowItWorksRow(number: 1, title: "Search each site", text: "Open a broker below and look yourself up on their site.")
                    HowItWorksRow(number: 2, title: "Ask for removal", text: "Follow the steps, or send the request Unlist writes for you.")
                    HowItWorksRow(number: 3, title: "Check back", text: "Unlist reminds you after 90 days in case your listing returns.")
                }
            }

            if !due.isEmpty {
                Section {
                    ForEach(due) { row in
                        DueRow(row: row, today: model.today,
                               searchAgain: { if let url = URL(string: row.broker.searchUrl) { openURL(url) } },
                               stillRemoved: { model.markStillRemoved(row.id) },
                               relisted: { model.setStatus(row.id, .relisted) })
                    }
                } header: {
                    Label("Due for recheck", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ViewStatus.due.color)
                } footer: {
                    Text("Search these sites again to make sure your listing hasn't come back.")
                }
            }

            Section {
                ForEach(visible) { row in
                    NavigationLink(value: row.id) { BrokerRowView(row: row) }
                }
                if visible.isEmpty {
                    Text("No brokers match.").foregroundStyle(.secondary)
                }
            } header: {
                Text(group.map { "\($0.label) · \(visible.count)" } ?? "All brokers · \(visible.count)")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Find a broker")
        .navigationTitle("Your removals")
    }
}

private struct SummaryView: View {
    let counts: Progress
    @Binding var group: TileGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("\(counts.removed) of \(counts.total)").font(.title2.bold()).monospacedDigit()
                + Text(" sites have removed you").foregroundStyle(.secondary))
                .accessibilityElement(children: .combine)
            ProgressBar(counts: counts)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(TileGroup.allCases) { tile in
                    TileButton(tile: tile, count: tile.count(in: counts), selected: group == tile) {
                        withAnimation(.snappy) { group = group == tile ? nil : tile }
                    }
                }
            }
        }
    }
}

private struct ProgressBar: View {
    let counts: Progress

    var body: some View {
        GeometryReader { geo in
            let total = max(counts.total, 1)
            let parts: [(Int, Color)] = [
                (counts.removed, ViewStatus.removed.color),
                (counts.due, ViewStatus.due.color),
                (counts.pending, ViewStatus.requestSent.color),
            ]
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    if part.0 > 0 {
                        part.1.frame(width: geo.size.width * CGFloat(part.0) / CGFloat(total))
                    }
                }
                Spacer(minLength: 0)
            }
            .background(Color(.systemGray5))
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

private struct TileButton: View {
    let tile: TileGroup
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: tile.symbol)
                    .font(.title3)
                    .foregroundStyle(tile.color)
                Text("\(count)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(tile.label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selected ? tile.color.opacity(0.12) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? tile.color : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) \(tile.label)")
        .accessibilityHint(selected ? "Shows all brokers" : "Shows only these brokers")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct HowItWorksRow: View {
    let number: Int
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DueRow: View {
    let row: BrokerRow
    let today: String
    let searchAgain: () -> Void
    let stillRemoved: () -> Void
    let relisted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: row.id) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.broker.name).font(.headline)
                    if let removed = row.record?.removedAt {
                        Text("Removed \(formatDate(removed)) · \(relativeDays(removed, today: today))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ViewThatFits {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var buttons: some View {
        Button("Search again", systemImage: "safari", action: searchAgain)
            .buttonStyle(.bordered)
        Button("Still removed", systemImage: "checkmark.circle", action: stillRemoved)
            .buttonStyle(.borderedProminent)
        Button("Re-listed", action: relisted)
            .buttonStyle(.bordered)
    }
}

struct BrokerRowView: View {
    let row: BrokerRow
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.broker.name).font(.headline)
                MethodLabel(method: row.broker.method)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                StatusPill(status: row.view)
                Text(nextStep(row))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
