import SwiftUI

enum AppTab: Hashable { case dashboard, profile }

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .dashboard
    @State private var path: [String] = []
    @State private var pendingTab: AppTab?

    var body: some View {
        if model.loadError != nil {
            DataErrorView()
        } else {
            TabView(selection: tabSelection) {
                NavigationStack(path: $path) {
                    DashboardView()
                        .navigationDestination(for: String.self) { BrokerDetailView(brokerId: $0) }
                }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppTab.dashboard)

                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
            }
            .task {
                if model.openBrokerId == nil, model.profile.fullName.trimmingCharacters(in: .whitespaces).isEmpty {
                    tab = .profile
                }
            }
            .confirmationDialog("You have unsaved changes to your details.",
                                isPresented: Binding(get: { pendingTab != nil }, set: { if !$0 { pendingTab = nil } }),
                                titleVisibility: .visible) {
                Button("Save") {
                    try? model.saveProfileDraft()
                    leaveProfile()
                }
                Button("Discard Changes", role: .destructive) {
                    model.discardProfileDraft()
                    leaveProfile()
                }
                Button("Keep Editing", role: .cancel) { pendingTab = nil }
            }
            .onChange(of: model.openProfile) { _, open in
                guard open else { return }
                tab = .profile
                model.openProfile = false
            }
            .onChange(of: model.openBrokerId, initial: true) { _, id in
                guard let id else { return }
                tab = .dashboard
                path = [id]
                model.openBrokerId = nil
            }
        }
    }

    /// Leaving the Profile tab with unsaved edits asks first.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { next in
                if tab == .profile, next != .profile, model.profileHasUnsavedChanges {
                    pendingTab = next
                } else {
                    tab = next
                }
            }
        )
    }

    private func leaveProfile() {
        if let next = pendingTab { tab = next }
        pendingTab = nil
    }
}
