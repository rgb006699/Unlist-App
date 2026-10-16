import Foundation
import Testing
@testable import Unlist

actor FakeScheduler: ReminderScheduler {
    var granted = true
    private(set) var permissionRequests = 0
    private(set) var scheduled: [[Reminder]] = []

    func requestPermissionIfNeeded() async -> Bool {
        permissionRequests += 1
        return granted
    }

    func replaceAll(with reminders: [Reminder]) async {
        scheduled.append(reminders)
    }
}

@MainActor
@Suite struct AppModelTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("unlist-model-\(UUID().uuidString)")
    let scheduler = FakeScheduler()
    let brokers = Array(Fixtures.brokers.prefix(3)) // spokeo, whitepages, acxiom

    func makeModel() -> AppModel {
        let model = AppModel(store: DataStore(directory: dir), brokers: brokers, scheduler: scheduler, today: { Fixtures.today })
        model.load()
        return model
    }

    func onDisk() throws -> DataFile { try DataStore(directory: dir).load() }

    @Test func freshLoadShowsEveryBrokerNotChecked() {
        let model = makeModel()
        #expect(model.rows.count == 3)
        #expect(model.rows.allSatisfy { $0.view == .notChecked })
        #expect(model.loadError == nil)
    }

    @Test func markingRemovedPersistsAndSchedulesAReminder() async throws {
        let model = makeModel()
        model.setStatus("spokeo", .removed)
        await model.reminderSync?.value
        #expect(try onDisk().records["spokeo"]?.recheckAt == "2027-01-13")
        #expect(await scheduler.scheduled.last?.map(\.id) == ["recheck-spokeo"])
        #expect(await scheduler.permissionRequests == 1)
    }

    @Test func leavingRemovedClearsTheReminder() async {
        let model = makeModel()
        model.setStatus("spokeo", .removed)
        model.setStatus("spokeo", .found)
        await model.reminderSync?.value
        #expect(await scheduler.scheduled.last == [])
    }

    @Test func revokedPermissionStillClearsStaleReminders() async {
        let model = makeModel()
        model.setStatus("spokeo", .removed)
        model.setStatus("acxiom", .removed)
        await model.reminderSync?.value
        #expect(await scheduler.scheduled.last?.count == 2)
        await scheduler.setGranted(false) // turned off in Settings
        model.setStatus("spokeo", .found)
        await model.reminderSync?.value
        // Can't add new ones without permission, but spokeo's must not linger.
        #expect(await !(scheduler.scheduled.last ?? []).contains { $0.brokerId == "spokeo" })
    }

    @Test func sameStatusTwiceAddsOneHistoryEntry() throws {
        let model = makeModel()
        model.setStatus("spokeo", .found)
        model.setStatus("spokeo", .found)
        #expect(try onDisk().records["spokeo"]?.history.count == 1)
    }

    @Test func notesOnANotCheckedBrokerMarkItFound() throws {
        let model = makeModel()
        model.updateNotes("whitepages", "called them")
        #expect(try onDisk().records["whitepages"]?.status == .found)
        #expect(try onDisk().records["whitepages"]?.notes == "called them")
        #expect(model.rows[1].view == .found)
    }

    @Test func stillRemovedOnlyForRemovedBrokers() throws {
        let model = makeModel()
        model.setStatus("spokeo", .found)
        model.markStillRemoved("spokeo")
        #expect(try onDisk().records["spokeo"]?.history.count == 1)
    }

    @Test func corruptFileBlocksSavesUntilRestored() throws {
        let model = makeModel()
        model.setStatus("spokeo", .found)
        model.setStatus("acxiom", .found)
        try Data("{oops".utf8).write(to: dir.appendingPathComponent("data.json"))
        model.load()
        #expect(model.loadError != nil)
        model.setStatus("whitepages", .found)
        #expect(String(decoding: try Data(contentsOf: dir.appendingPathComponent("data.json")), as: UTF8.self) == "{oops")
        model.restore()
        #expect(model.loadError == nil)
        #expect(model.rows[0].view == .found)
    }

    @Test func orphanRecordSurvivesSaves() throws {
        var d = DataFile.empty()
        d.records["retired"] = applyStatus(nil, .found, today: Fixtures.today, recheckDays: 90)
        try DataStore(directory: dir).save(d)
        let model = makeModel()
        model.setStatus("spokeo", .found)
        #expect(try onDisk().records["retired"] != nil)
    }

    @Test func savingTheProfilePersists() throws {
        let model = makeModel()
        try model.saveProfile(Fixtures.profile)
        #expect(try onDisk().profile == Fixtures.profile)
        #expect(model.profile == Fixtures.profile)
    }
}

extension FakeScheduler {
    func setGranted(_ value: Bool) { granted = value }
}

@MainActor
@Suite struct ProfileDraftTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("unlist-draft-\(UUID().uuidString)")

    func makeModel() -> AppModel {
        let model = AppModel(store: DataStore(directory: dir), brokers: Fixtures.brokers, scheduler: FakeScheduler(), today: { Fixtures.today })
        model.load()
        return model
    }

    @Test func draftStartsClean() {
        let model = makeModel()
        #expect(model.profileDraft == .empty)
        #expect(!model.profileHasUnsavedChanges)
    }

    @Test func editingMarksUnsavedAndSavingCleansAndPersists() throws {
        let model = makeModel()
        model.profileDraft.fullName = " Jane "
        model.profileDraft.aliases = ["", "JD"]
        #expect(model.profileHasUnsavedChanges)
        try model.saveProfileDraft()
        #expect(!model.profileHasUnsavedChanges)
        #expect(model.profile.fullName == "Jane")
        #expect(model.profileDraft.aliases == ["JD"])
        #expect(try DataStore(directory: dir).load().profile.fullName == "Jane")
    }

    @Test func discardRestoresTheSavedProfile() {
        let model = makeModel()
        model.profileDraft.fullName = "Typo"
        model.discardProfileDraft()
        #expect(model.profileDraft == .empty)
        #expect(!model.profileHasUnsavedChanges)
    }
}
