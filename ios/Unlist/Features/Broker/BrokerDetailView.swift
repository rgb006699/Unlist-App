import SwiftUI

struct BrokerDetailView: View {
    let brokerId: String

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var notes = ""
    @State private var listingUrl = ""
    @State private var remindersOff = false
    @State private var browser: BrowserTarget?
    @State private var pendingStatus: Status?
    @FocusState private var focus: Field?

    private enum Field { case url, notes }

    var body: some View {
        if let row = model.row(brokerId) {
            content(row)
        } else {
            ContentUnavailableView("Broker not found", systemImage: "questionmark.circle",
                                   description: Text("This broker isn't in Unlist's list."))
        }
    }

    private func content(_ row: BrokerRow) -> some View {
        let broker = row.broker
        let record = row.record

        return List {
            Section {
                HeaderView(row: row, group: model.groupMembers(of: brokerId), search: searchLink(for: broker, profile: model.profile)) { url in
                    browser = BrowserTarget(brokerId: brokerId, url: url)
                }
            }

            Section {
                Picker("Status", selection: statusBinding(record)) {
                    if record == nil { Text("Not checked").tag(Status?.none) }
                    ForEach(Status.allCases, id: \.self) { Text($0.label).tag(Status?.some($0)) }
                }
                .pickerStyle(.menu)

                Label(row.view.help, systemImage: "info.circle")
                    .labelStyle(CompactLabelStyle(spacing: 8))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(dates(record), id: \.0) { label, iso in
                    LabeledContent(label) {
                        Text("\(formatDate(iso)) · \(relativeDays(iso, today: model.today))")
                            .monospacedDigit()
                    }
                }

                if remindersOff {
                    Label("Reminders are off. Turn on notifications for Unlist in Settings to get a recheck reminder.",
                          systemImage: "bell.slash")
                        .labelStyle(CompactLabelStyle(spacing: 8))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Your progress", systemImage: "checklist")
            }

            Section {
                TextField("https://…", text: $listingUrl)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .url)
                    .onSubmit { model.updateListingUrl(brokerId, listingUrl) }
            } header: {
                Text("Listing URL")
            } footer: {
                Text("Paste the address of the page that shows your information.")
            }

            Section {
                TextField("e.g. Called on Oct 3, they said 7 days", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($focus, equals: .notes)
            } header: {
                Text("Notes")
            } footer: {
                Text("Saved when you finish editing.")
            }

            Section {
                ForEach(Array(broker.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.footnote.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                        Text(step)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Label("How to opt out", systemImage: "list.number")
            }

            RequestSection(broker: broker, profile: model.profile, listingUrl: listingUrl)

            if let history = record?.history, !history.isEmpty {
                Section {
                    ForEach(Array(history.reversed().enumerated()), id: \.offset) { _, entry in
                        LabeledContent {
                            Text(formatDate(entry.at)).monospacedDigit()
                        } label: {
                            Text(historyLabel(entry.status))
                        }
                    }
                } header: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(broker.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            notes = record?.notes ?? ""
            listingUrl = record?.listingUrl ?? ""
        }
        .onChange(of: focus) { old, _ in
            if old == .url { model.updateListingUrl(brokerId, listingUrl) }
            if old == .notes { model.updateNotes(brokerId, notes) }
        }
        .onDisappear { saveText() }
        .onChange(of: scenePhase) { _, phase in
            // Swiping the app away doesn't end editing, so save on the way out.
            if phase != .active { saveText() }
        }
        .task(id: record?.status) {
            remindersOff = record?.status == .removed ? await NotificationScheduler.isDenied() : false
        }
        .sheet(item: $browser) { BrokerBrowserView(target: $0) }
        .confirmationDialog("Apply to all \(model.groupMembers(of: brokerId).count) sites in this group?",
                            isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } }),
                            titleVisibility: .visible) {
            Button("Apply to all") {
                if let s = pendingStatus { model.setStatus(brokerId, s, applyToGroup: true) }
                pendingStatus = nil
            }
            Button("Just this one") {
                if let s = pendingStatus { model.setStatus(brokerId, s) }
                pendingStatus = nil
            }
            Button("Cancel", role: .cancel) { pendingStatus = nil }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
    }

    private func saveText() {
        model.updateListingUrl(brokerId, listingUrl)
        model.updateNotes(brokerId, notes)
    }

    private func statusBinding(_ record: BrokerRecord?) -> Binding<Status?> {
        Binding(
            get: { record?.status },
            set: { s in
                guard let s else { return }
                // A shared opt-out asks whether the change covers every site in it.
                if model.groupMembers(of: brokerId).count > 1 { pendingStatus = s } else { model.setStatus(brokerId, s) }
            }
        )
    }

    private func dates(_ record: BrokerRecord?) -> [(String, String)] {
        guard let record else { return [] }
        var out: [(String, String)] = []
        if let d = record.requestSentAt { out.append(("Request sent", d)) }
        // An earlier removal stays in History; here it would read as current.
        if record.status == .removed, let d = record.removedAt { out.append(("Removed", d)) }
        if let d = record.recheckAt { out.append(("Recheck", d)) }
        return out
    }

    private func historyLabel(_ s: HistoryStatus) -> String {
        switch s {
        case .status(let status): status.label
        case .rechecked: "Rechecked — still removed"
        }
    }
}

private struct HeaderView: View {
    let row: BrokerRow
    let group: [Broker]
    let search: SearchLink
    let open: (URL) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let broker = row.broker
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(broker.name).font(.title2.bold())
                Spacer()
                StatusPill(status: row.view)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("Removal by \(broker.method.label.lowercased())", systemImage: broker.method.symbol)
                Label(broker.relistRisk.label, systemImage: "arrow.triangle.2.circlepath")
                Label(broker.lastVerified.isEmpty ? "Opt-out info not yet verified" : "Info checked \(formatDate(broker.lastVerified))",
                      systemImage: "checkmark.shield")
            }
            .labelStyle(CompactLabelStyle(spacing: 8))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            let needs = [broker.needsCaptcha ? "CAPTCHA" : nil, broker.needsEmailConfirm ? "Email confirmation" : nil,
                         broker.needsId ? "ID required" : nil].compactMap { $0 }
            if !needs.isEmpty {
                Text("This site asks for: \(needs.joined(separator: " · "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if group.count > 1 {
                Label("One opt-out covers \(group.count) sites: \(group.map(\.name).joined(separator: ", ")).",
                      systemImage: "square.stack.3d.up")
                    .labelStyle(CompactLabelStyle(spacing: 8))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout { links(broker) }

            if case .fallback(_, let missing) = search, !missing.isEmpty {
                Label("Add your \(missing.joined(separator: " and ")) in Profile to jump straight to your results.",
                      systemImage: "info.circle")
                    .labelStyle(CompactLabelStyle(spacing: 8))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var isDirect: Bool {
        if case .direct = search { return true }
        return false
    }

    @ViewBuilder
    private func links(_ broker: Broker) -> some View {
        Button {
            switch search {
            case .direct(let url), .fallback(let url, _): open(url)
            }
        } label: {
            Label(isDirect ? "Find me" : "Search page", systemImage: "magnifyingglass").labelStyle(.compact)
                .frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.85)
        }
        .buttonStyle(.bordered)
        if let url = URL(string: broker.optOutUrl) {
            Button { open(url) } label: {
                Label("Opt-out page", systemImage: "arrow.up.right").labelStyle(.compact)
                    .frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.85)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
