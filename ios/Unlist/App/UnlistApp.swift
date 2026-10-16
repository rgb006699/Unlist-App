import SwiftUI
import UserNotifications

@main
struct UnlistApp: App {
    @State private var model: AppModel
    private let notifications = NotificationDelegate()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Load before handing the model to @State: reading `_model.wrappedValue`
        // here would load a throwaway copy, not the one the views use.
        let model = AppModel(store: .appDefault(), brokers: BrokerList.bundled(), scheduler: NotificationScheduler())
        model.load()
        _model = State(initialValue: model)

        notifications.onOpenBroker = { id in model.openBrokerId = id }
        UNUserNotificationCenter.current().delegate = notifications
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
