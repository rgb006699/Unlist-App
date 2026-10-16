import SwiftUI

/// Which broker page to show in the in-app browser.
struct BrowserTarget: Identifiable, Hashable {
    let id = UUID()
    let brokerId: String
    let url: URL
}

/// A broker's site inside Unlist, with Fill, copy chips and status shortcuts.
struct BrokerBrowserView: View {
    let target: BrowserTarget

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var state: BrowserState
    @State private var message: String?
    @State private var pendingStatus: Status?
    @State private var filling = false

    init(target: BrowserTarget) {
        self.target = target
        _state = State(initialValue: BrowserState(url: target.url))
    }

    private var broker: Broker? { model.brokers.first { $0.id == target.brokerId } }
    private var hasDetails: Bool { !autofillValues(model.profile).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(state: state)
                    .ignoresSafeArea(edges: .bottom)
                if let error = state.errorText {
                    ContentUnavailableView {
                        Label("Couldn't load the page", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try again") { state.reload() }.buttonStyle(.borderedProminent)
                    }
                    .background(.background)
                }
            }
            .overlay(alignment: .top) {
                if state.isLoading { ProgressView().progressViewStyle(.linear).tint(.accentColor) }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle(state.host)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Reload", systemImage: "arrow.clockwise") { state.reload() }
                    if let url = state.currentURL {
                        ShareLink(item: url) { Label("Open in Safari or share", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .confirmationDialog(groupQuestion, isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } }),
                                titleVisibility: .visible) {
                Button("Apply to all") { apply(applyToGroup: true) }
                Button("Just this one") { apply(applyToGroup: false) }
                Button("Cancel", role: .cancel) { pendingStatus = nil }
            }
        }
    }

    private var groupQuestion: String {
        "Apply to all \(model.groupMembers(of: target.brokerId).count) sites in this group?"
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if hasDetails {
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack(spacing: 8) {
                    Button {
                        Task { await fill() }
                    } label: {
                        Label("Fill my details", systemImage: "wand.and.stars")
                            .labelStyle(.compact)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(filling || state.isLoading)

                    markMenu
                }
                .padding(.horizontal)
                DetailsBar(profile: model.profile)
            } else {
                VStack(spacing: 8) {
                    Text("Add your details in Profile first, so Unlist can fill them in for you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Profile") {
                        model.openProfile = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var markMenu: some View {
        Menu {
            Button("Found my listing", systemImage: ViewStatus.found.symbol) { mark(.found) }
            Button("Request sent", systemImage: ViewStatus.requestSent.symbol) { mark(.requestSent) }
            Button("Confirmed removed", systemImage: ViewStatus.removed.symbol) { mark(.removed) }
        } label: {
            Label("Mark as", systemImage: "checklist")
                .labelStyle(.compact)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func mark(_ status: Status) {
        if model.groupMembers(of: target.brokerId).count > 1 {
            pendingStatus = status
        } else {
            model.setStatus(target.brokerId, status)
            message = "Marked as \(status.label.lowercased())."
        }
    }

    private func apply(applyToGroup: Bool) {
        guard let status = pendingStatus else { return }
        model.setStatus(target.brokerId, status, applyToGroup: applyToGroup)
        message = applyToGroup ? "Marked all sites in this group as \(status.label.lowercased())." : "Marked as \(status.label.lowercased())."
        pendingStatus = nil
    }

    private func fill() async {
        filling = true
        let count = await state.fill(payload: autofillPayload(model.profile, selectors: broker?.autofill))
        filling = false
        message = count == 0
            ? "No empty fields to fill on this page. Use the copy buttons below."
            : "Filled \(count) field\(count == 1 ? "" : "s") — check them, then submit."
    }
}
