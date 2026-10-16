import SwiftUI

enum AppTab: Hashable { case dashboard, profile }

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .dashboard
    @State private var path: [String] = []

    var body: some View {
        if model.loadError != nil {
            DataErrorView()
        } else {
            TabView(selection: $tab) {
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
                if model.profile.fullName.trimmingCharacters(in: .whitespaces).isEmpty { tab = .profile }
            }
            .onChange(of: model.openBrokerId) { _, id in
                guard let id else { return }
                tab = .dashboard
                path = [id]
                model.openBrokerId = nil
            }
        }
    }
}
