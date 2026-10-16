import Foundation
import Observation

/// Owns the data file and applies the same rules as the web API's PATCH and
/// PUT routes. Every change is saved straight away and reminders re-synced.
@MainActor
@Observable
final class AppModel {
    let brokers: [Broker]
    private(set) var data: DataFile?
    private(set) var loadError: StoreError?
    private(set) var saveError: String?
    private(set) var today: String
    /// The Profile form edits this copy; it is saved explicitly.
    var profileDraft: Profile = .empty
    /// Set when a reminder is tapped; the UI opens that broker.
    var openBrokerId: String?
    /// The latest reminder sync, so tests (and callers) can wait for it.
    private(set) var reminderSync: Task<Void, Never>?

    @ObservationIgnored private let store: DataStore
    @ObservationIgnored private let scheduler: ReminderScheduler
    @ObservationIgnored private let todayProvider: () -> String

    init(store: DataStore, brokers: [Broker], scheduler: ReminderScheduler, today: @escaping () -> String = { todayISO() }) {
        self.store = store
        self.brokers = brokers
        self.scheduler = scheduler
        self.todayProvider = today
        self.today = today()
    }

    var rows: [BrokerRow] {
        mergeBrokers(brokers, data?.records ?? [:], today: today)
    }

    var progress: Progress { Unlist.progress(rows.map(\.view)) }

    var profile: Profile { data?.profile ?? .empty }

    var profileHasUnsavedChanges: Bool { profileDraft != profile }

    func row(_ id: String) -> BrokerRow? { rows.first { $0.broker.id == id } }

    // MARK: Loading

    func load() {
        today = todayProvider()
        do {
            data = try store.load()
            loadError = nil
            profileDraft = profile
            syncReminders()
        } catch let error as StoreError {
            data = nil
            loadError = error
        } catch {
            data = nil
            loadError = .corrupt(error.localizedDescription)
        }
    }

    /// Called when the app comes back to the foreground, so "due" stays current.
    func refreshToday() { today = todayProvider() }

    func restore() {
        do {
            data = try store.restore()
            loadError = nil
            profileDraft = profile
            syncReminders()
        } catch StoreError.nothingToRestore {
            load() // fixed by hand in the meantime
        } catch let error as StoreError {
            loadError = error
        } catch {
            loadError = .corrupt(error.localizedDescription)
        }
    }

    // MARK: Changes

    func setStatus(_ id: String, _ status: Status) {
        mutateRecord(id) { rec, d in
            guard rec?.status != status else { return rec }
            return applyStatus(rec, status, today: today, recheckDays: d.settings.recheckDays)
        }
    }

    func markStillRemoved(_ id: String) {
        mutateRecord(id) { rec, d in
            guard let rec, rec.status == .removed else { return rec }
            return Unlist.markStillRemoved(rec, today: today, recheckDays: d.settings.recheckDays)
        }
    }

    func updateNotes(_ id: String, _ notes: String) {
        updateText(id) { $0.notes = notes } unchanged: { $0?.notes ?? "" == notes }
    }

    func updateListingUrl(_ id: String, _ url: String) {
        updateText(id) { $0.listingUrl = url } unchanged: { $0?.listingUrl ?? "" == url }
    }

    func saveProfile(_ profile: Profile) throws {
        guard var d = data, loadError == nil else { throw StoreError.corrupt("Your data couldn't be read") }
        d.profile = profile
        try store.save(d)
        data = d
    }

    func saveProfileDraft() throws {
        let cleaned = cleanProfile(profileDraft)
        try saveProfile(cleaned)
        profileDraft = cleaned
    }

    func discardProfileDraft() { profileDraft = profile }

    func clearSaveError() { saveError = nil }

    // MARK: Helpers

    /// Notes or a listing URL on a not-checked broker create a "found" record.
    private func updateText(_ id: String, _ apply: (inout BrokerRecord) -> Void, unchanged: (BrokerRecord?) -> Bool) {
        mutateRecord(id) { rec, d in
            guard !unchanged(rec) else { return rec }
            var next = rec ?? applyStatus(nil, .found, today: today, recheckDays: d.settings.recheckDays)
            apply(&next)
            return next
        }
    }

    private func mutateRecord(_ id: String, _ change: (BrokerRecord?, DataFile) -> BrokerRecord?) {
        guard var d = data, loadError == nil, brokers.contains(where: { $0.id == id }) else { return }
        let before = d.records[id]
        guard let after = change(before, d), after != before else { return }
        d.records[id] = after
        do {
            try store.save(d)
            data = d
            syncReminders()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func syncReminders() {
        let list = reminders(for: rows)
        let previous = reminderSync
        let scheduler = scheduler
        reminderSync = Task {
            await previous?.value
            if !list.isEmpty, await !scheduler.requestPermissionIfNeeded() { return }
            await scheduler.replaceAll(with: list)
        }
    }
}

