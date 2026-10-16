import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var justSaved = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                Label("Unlist uses these details to fill in your removal requests. They're saved only on this iPhone.",
                      systemImage: "lock.shield")
                    .labelStyle(CompactLabelStyle(spacing: 10))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Full name", text: $model.profileDraft.fullName)
                    .textContentType(.name)
                    .focused($focused)
            } header: {
                Text("Full name")
            } footer: {
                Text("Your legal name, the way people-search sites would show it.")
            }

            listSection(title: "Other names", item: "Other name", footer: "Maiden names, nicknames or other spellings sites might use.",
                        keyPath: \.aliases, contentType: .name, keyboard: .default)

            ForEach(model.profileDraft.addresses.indices, id: \.self) { index in
                addressSection(index)
            }
            Section {
                Button("Add address", systemImage: "plus.circle.fill") {
                    model.profileDraft.addresses.append(Address(current: model.profileDraft.addresses.isEmpty))
                }
            } footer: {
                Text("Add past addresses too — brokers often list old ones.")
            }

            listSection(title: "Phone numbers", item: "Phone", footer: nil,
                        keyPath: \.phones, contentType: .telephoneNumber, keyboard: .phonePad)
            listSection(title: "Email addresses", item: "Email", footer: "People-search sites often show these too.",
                        keyPath: \.emails, contentType: .emailAddress, keyboard: .emailAddress)
        }
        .navigationTitle("Your details")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if justSaved {
                        Label("Saved", systemImage: "checkmark").labelStyle(.titleAndIcon)
                    } else {
                        Text("Save").bold()
                    }
                }
                .disabled(!model.profileHasUnsavedChanges && !justSaved)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        hideKeyboard()
        do {
            try model.saveProfileDraft()
            justSaved = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                justSaved = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Lists of single values (names, phones, emails)

    private func binding(_ keyPath: WritableKeyPath<Profile, [String]>, _ index: Int) -> Binding<String> {
        Binding(
            get: {
                let list = model.profileDraft[keyPath: keyPath]
                return index < list.count ? list[index] : ""
            },
            set: { value in
                guard index < model.profileDraft[keyPath: keyPath].count else { return }
                model.profileDraft[keyPath: keyPath][index] = value
            }
        )
    }

    @ViewBuilder
    private func listSection(title: String, item: String, footer: String?, keyPath: WritableKeyPath<Profile, [String]>,
                             contentType: UITextContentType, keyboard: UIKeyboardType) -> some View {
        let values = model.profileDraft[keyPath: keyPath]
        Section {
            ForEach(values.indices, id: \.self) { index in
                TextField(item, text: binding(keyPath, index))
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard != .default)
                    .accessibilityLabel("\(item) \(index + 1)")
            }
            .onDelete { model.profileDraft[keyPath: keyPath].remove(atOffsets: $0) }

            Button("Add \(item.lowercased())", systemImage: "plus.circle.fill") {
                model.profileDraft[keyPath: keyPath].append("")
            }
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }

    // MARK: Addresses

    private func address(_ index: Int) -> Binding<Address> {
        Binding(
            get: { index < model.profileDraft.addresses.count ? model.profileDraft.addresses[index] : Address() },
            set: { value in
                guard index < model.profileDraft.addresses.count else { return }
                model.profileDraft.addresses[index] = value
            }
        )
    }

    private func addressSection(_ index: Int) -> some View {
        let a = address(index)
        return Section {
            Toggle("I live here now", isOn: Binding(
                get: { a.wrappedValue.current },
                set: { isCurrent in
                    for i in model.profileDraft.addresses.indices {
                        model.profileDraft.addresses[i].current = isCurrent && i == index
                    }
                }
            ))
            TextField("Street", text: a.street).textContentType(.streetAddressLine1)
            TextField("City", text: a.city).textContentType(.addressCity)
            HStack {
                TextField("State", text: a.state)
                    .textContentType(.addressState)
                    .textInputAutocapitalization(.characters)
                Divider()
                TextField("ZIP", text: a.zip)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
            }
            Button("Remove address", systemImage: "trash", role: .destructive) {
                if index < model.profileDraft.addresses.count { model.profileDraft.addresses.remove(at: index) }
            }
            .foregroundStyle(.red)
        } header: {
            Text(a.wrappedValue.current ? "Current address" : "Address \(index + 1)")
        }
    }
}
