import MessageUI
import SwiftUI

/// The system email composer, pre-filled. The owner reviews and taps Send.
struct MailComposer: UIViewControllerRepresentable {
    let recipient: String?
    let subject: String
    let body: String

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        nonisolated func mailComposeController(_ controller: MFMailComposeViewController,
                                               didFinishWith result: MFMailComposeResult, error: Error?) {
            MainActor.assumeIsolated { controller.dismiss(animated: true) }
        }
    }
}
