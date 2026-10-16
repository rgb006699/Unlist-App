import MessageUI
import SwiftUI

/// The system email composer, pre-filled. The owner reviews and taps Send.
struct MailComposer: UIViewControllerRepresentable {
    let recipient: String?
    let subject: String
    let body: String
    /// Called when the composer closes (sent, saved or cancelled).
    var onFinish: () -> Void = {}

    static var isAvailable: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if let recipient { vc.setToRecipients([recipient]) }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    // MessageUI calls its delegate on the main thread.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish()
        }
    }
}
