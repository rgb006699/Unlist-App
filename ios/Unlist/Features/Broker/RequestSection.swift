import SwiftUI
import UIKit

/// The ready-to-send removal email. Unlist never sends it; the owner does.
struct RequestSection: View {
    let broker: Broker
    let profile: Profile
    let listingUrl: String

    @Environment(\.openURL) private var openURL
    @State private var template: TemplateID = .tdpsa
    @State private var showComposer = false
    @State private var copied = false
    @State private var mailUnavailable = false

    var body: some View {
        let filled = fillTemplate(template, profile: profile, broker: broker, listingUrl: listingUrl)

        Section {
            Text("A ready-to-send email asking \(broker.name) to delete your information. Texas residents can cite the Texas privacy law; the general version works anywhere.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Template", selection: $template) {
                ForEach(TemplateID.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Subject").font(.caption).foregroundStyle(.secondary)
                Text(filled.subject).font(.subheadline.weight(.semibold))
                Divider()
                Text(filled.body)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)

            ViewThatFits {
                HStack(spacing: 8) { actions(filled) }
                VStack(alignment: .leading, spacing: 8) { actions(filled) }
            }
        } header: {
            Label("Removal request", systemImage: "doc.text")
        } footer: {
            Label(broker.optOutEmail == nil
                  ? "Unlist never sends anything. This broker has no opt-out email, so add the recipient yourself."
                  : "Unlist never sends anything. You review and send the request yourself.",
                  systemImage: "lock")
            .labelStyle(.compact)
        }
        .sheet(isPresented: $showComposer) {
            MailComposer(recipient: broker.optOutEmail, subject: filled.subject, body: filled.body,
                         onFinish: { showComposer = false })
                .ignoresSafeArea()
        }
        .alert("Couldn't open Mail", isPresented: $mailUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Copy the request or share it to another app instead.")
        }
    }

    @ViewBuilder
    private func actions(_ filled: (subject: String, body: String)) -> some View {
        Button("Email", systemImage: "envelope") {
            if MailComposer.isAvailable {
                showComposer = true
            } else {
                openURL(mailtoURL(to: broker.optOutEmail, subject: filled.subject, body: filled.body)) { accepted in
                    if !accepted { mailUnavailable = true }
                }
            }
        }
        .buttonStyle(.borderedProminent)

        Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
            UIPasteboard.general.string = "\(filled.subject)\n\n\(filled.body)"
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
        .buttonStyle(.bordered)

        ShareLink(item: filled.body, subject: Text(filled.subject)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
    }
}
