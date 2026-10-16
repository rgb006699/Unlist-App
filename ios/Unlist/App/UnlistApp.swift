import SwiftUI

@main
struct UnlistApp: App {
    @State private var model = AppModel(store: .appDefault(), brokers: BrokerList.bundled(), scheduler: NotificationScheduler())
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _model.wrappedValue.load()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshToday() }
                }
        }
    }
}
