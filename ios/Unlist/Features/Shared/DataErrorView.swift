import SwiftUI

/// Shown instead of the app when the data file can't be read. Nothing is
/// overwritten until the owner chooses to restore.
struct DataErrorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Your data couldn't be read", systemImage: "exclamationmark.triangle")
        } description: {
            switch model.loadError {
            case .noBackup:
                Text("There's no backup to restore from. Your unreadable file hasn't been changed.")
            default:
                Text("Unlist can restore the version from before your last change. The unreadable file is kept next to it.")
            }
        } actions: {
            if model.loadError != .noBackup {
                Button("Restore from backup", systemImage: "arrow.counterclockwise") { model.restore() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
