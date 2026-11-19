import CloudKit
import Foundation

enum CloudConfig {
    static let containerID = "iCloud.de.timroot.sprachduett"
    static let recordType = "DuoState"
    static let recordName = "state"

    static func zoneName(duoID: String) -> String { "Duo-\(duoID)" }

    static func duoID(from zoneName: String) -> String? {
        guard zoneName.hasPrefix("Duo-") else { return nil }
        let id = String(zoneName.dropFirst(4))
        return id.isEmpty ? nil : id
    }

    /// Ohne diese Berechtigung beendet jeder CloudKit-Aufruf die App.
    static var isCompiledIn: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "SprachduettCloudKitEnabled") as? String
        return value?.uppercased() == "YES"
    }
}

@MainActor
final class SyncHub: ObservableObject {
    static let shared = SyncHub()

    enum Status: Equatable {
        case unavailableInBuild, solo, noAccount, starting, idle, syncing, error(String)

        var text: String {
            switch self {
            case .unavailableInBuild: return "iCloud ist in dieser Version nicht eingebaut"
            case .solo: return "Solo, nur auf diesem iPhone"
            case .noAccount: return "Nicht bei iCloud angemeldet"
            case .starting: return "Verbindet sich mit iCloud …"
            case .idle: return "Aktuell"
            case .syncing: return "Gleichstand …"
            case .error(let message): return message
            }
        }
    }

    @Published private(set) var status: Status = CloudConfig.isCompiledIn ? .solo : .unavailableInBuild
    @Published var alertTitle = "iCloud"
    @Published var alertMessage: String?
    @Published var focusDuo = false
    private(set) var container: CKContainer?
    private var acceptingZones = Set<String>()
    private weak var model: AppModel?
    private var privateEngine: CKSyncEngine?
    private var sharedEngine: CKSyncEngine?
    private var privateDelegate: SyncDelegate?
    private var sharedDelegate: SyncDelegate?

    var canShare: Bool { privateEngine != nil && model?.persisted.isSharedZone == false }

    func start(model: AppModel) async {
        self.model = model
        guard CloudConfig.isCompiledIn else {
            status = .unavailableInBuild
            return
        }
        guard privateEngine == nil else { return }
        status = .starting
        let ck = CKContainer(identifier: CloudConfig.containerID)
        container = ck
        do {
            guard try await ck.accountStatus() == .available else {
                status = .noAccount
                return
            }
            let me = try await ck.userRecordID()
            model.adoptCloudUser(me.recordName)
        } catch {
            report(error, context: "iCloud lässt sich nicht verbinden.")
            return
        }
        let owned = SyncDelegate(scope: .private)
        let shared = SyncDelegate(scope: .shared)
        privateDelegate = owned
        sharedDelegate = shared
        privateEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: ck.privateCloudDatabase,
            stateSerialization: loadState(.private),
            delegate: owned
        ))
        sharedEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: ck.sharedCloudDatabase,
            stateSerialization: loadState(.shared),
            delegate: shared
        ))
        status = model.persisted.sharingStarted ? .idle : .solo
        await syncNow()
    }

    func syncNow() async {
        guard let privateEngine, let sharedEngine else { return }
        status = .syncing
        do {
            try await privateEngine.fetchChanges()
            try await sharedEngine.fetchChanges()
            try await privateEngine.sendChanges()
            try await sharedEngine.sendChanges()
            status = .idle
        } catch {
            report(error, context: "Der Abgleich mit iCloud ist fehlgeschlagen.")
        }
    }

    func push() {
        enqueueCurrentState()
        Task { await syncNow() }
    }

    func enqueueCurrentState() {
        guard let model, model.persisted.sharingStarted || model.persisted.isSharedZone else { return }
        guard let engine = engine(forShared: model.persisted.isSharedZone) else { return }
        let zone = zoneID(model)
        if !model.persisted.isSharedZone {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
        }
        let recordID = CKRecord.ID(recordName: CloudConfig.recordName, zoneID: zone)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func report(_ error: Error, context: String) {
        let text = "\(context)\n\n\(CloudKitDiagnostics.describe(error))"
        alertTitle = "iCloud"
        alertMessage = text
        status = .error(context)
    }

    func report(_ message: String) {
        alertTitle = "iCloud"
        alertMessage = message
        status = .error(message)
    }

    func makeShare() async throws -> CKShare {
        guard let ck = container, let model, canShare else { throw ShareFailure.unavailable }
        model.beginSharing()
        let zone = zoneID(model)
        let db = ck.privateCloudDatabase
        _ = try await db.save(CKRecordZone(zoneID: zone))
        enqueueCurrentState()
        try await syncNow()
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)
        if let existing = try? await db.record(for: shareID) as? CKShare {
            return existing
        }
        let share = CKShare(recordZoneID: zone)
        share[CKShare.SystemFieldKey.title] = "Sprachduett" as CKRecordValue
        share.publicPermission = .none
        _ = try await db.modifyRecords(saving: [share], deleting: [])
        return share
    }

    func accept(_ metadata: CKShare.Metadata) async {
        guard CloudConfig.isCompiledIn else {
            report("Diese Installation hat kein iCloud. Die Einladung kann nicht angenommen werden.")
            return
        }
        let zone = metadata.share.recordID.zoneID
        let key = "\(zone.ownerName)/\(zone.zoneName)"
        guard acceptingZones.insert(key).inserted else { return }
        defer { acceptingZones.remove(key) }
        if container == nil, let model { await start(model: model) }
        guard let ck = container, let model else {
            report("iCloud ist noch nicht verbunden. Öffne die App und versuch den Link noch einmal.")
            return
        }
        do {
            _ = try await ck.accept(metadata)
            let duoID = CloudConfig.duoID(from: zone.zoneName) ?? zone.zoneName
            model.noteSharedZone(ownerName: zone.ownerName, duoID: duoID)
            await syncNow()
            focusDuo = true
            if case .error = status { return }
            alertTitle = "Duo"
            alertMessage = "Die Einladung ist angenommen. Ihr seid jetzt ein Duo."
        } catch {
            if model.persisted.isSharedZone, model.persisted.zoneOwnerName == zone.ownerName {
                focusDuo = true
                alertTitle = "Duo"
                alertMessage = "Du bist schon in diesem Duo."
                return
            }
            report(error, context: "Die Einladung konnte nicht angenommen werden.")
        }
    }

    func buildRecords(for changes: [CKSyncEngine.PendingRecordZoneChange]) -> [CKRecord.ID: CKRecord] {
        guard let model else { return [:] }
        var out: [CKRecord.ID: CKRecord] = [:]
        for change in changes {
            guard case .saveRecord(let recordID) = change else { continue }
            guard recordID.recordName == CloudConfig.recordName else { continue }
            let record = SystemFieldsCache.record(id: recordID)
            if let data = try? JSONEncoder().encode(model.persisted.duo),
               let json = String(data: data, encoding: .utf8) {
                record["json"] = json as NSString
                record["updatedAt"] = model.persisted.duo.updatedAt as NSDate
            }
            out[recordID] = record
        }
        return out
    }

    func handle(_ event: CKSyncEngine.Event, scope: CKDatabase.Scope) {
        guard let model else { return }
        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization, scope)
        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                stopEngines()
                status = .noAccount
            default:
                break
            }
        case .fetchedRecordZoneChanges(let update):
            var shouldPush = false
            for modification in update.modifications {
                if apply(modification.record, model: model) { shouldPush = true }
            }
            if shouldPush { push() }
        case .sentRecordZoneChanges(let update):
            for record in update.savedRecords { SystemFieldsCache.store(record) }
            for failure in update.failedRecordSaves {
                switch failure.error.code {
                case .serverRecordChanged:
                    if let server = failure.error.serverRecord, apply(server, model: model) { push() }
                case .zoneNotFound:
                    if scope == .private {
                        privateEngine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: failure.record.recordID.zoneID))])
                    }
                    engine(forShared: scope == .shared)?.state.add(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
                case .unknownItem:
                    SystemFieldsCache.remove(failure.record.recordID.recordName)
                    engine(forShared: scope == .shared)?.state.add(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
                case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
                    break
                default:
                    report(failure.error, context: "Ein Duo-Eintrag konnte nicht gespeichert werden.")
                }
            }
        default:
            break
        }
    }

    private func apply(_ record: CKRecord, model: AppModel) -> Bool {
        guard record.recordType == CloudConfig.recordType,
              let json = record["json"] as? String,
              let data = json.data(using: .utf8),
              let remote = try? JSONDecoder().decode(DuoCloudState.self, from: data) else { return false }
        SystemFieldsCache.store(record)
        return model.applyRemote(remote)
    }

    private func zoneID(_ model: AppModel) -> CKRecordZone.ID {
        let name = CloudConfig.zoneName(duoID: model.persisted.duo.duoID)
        let owner = model.persisted.isSharedZone && !model.persisted.zoneOwnerName.isEmpty
            ? model.persisted.zoneOwnerName
            : CKCurrentUserDefaultName
        return CKRecordZone.ID(zoneName: name, ownerName: owner)
    }

    private func engine(forShared shared: Bool) -> CKSyncEngine? {
        shared ? sharedEngine : privateEngine
    }

    private func stopEngines() {
        privateEngine = nil
        sharedEngine = nil
        privateDelegate = nil
        sharedDelegate = nil
    }

    private func stateKey(_ scope: CKDatabase.Scope) -> String {
        scope == .shared ? "ckState.shared" : "ckState.private"
    }

    private func loadState(_ scope: CKDatabase.Scope) -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(scope)) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ state: CKSyncEngine.State.Serialization, _ scope: CKDatabase.Scope) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey(scope))
        }
    }
}

enum ShareFailure: LocalizedError {
    case unavailable
    var errorDescription: String? { "iCloud-Freigabe ist gerade nicht verfügbar. Bist du bei iCloud angemeldet?" }
}

enum CloudKitDiagnostics {
    static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else {
            return error.localizedDescription
        }
        var lines = ["CKError \(ck.errorCode) (\(ck.code))"]
        if let reason = ck.localizedDescription.nilIfBlank { lines.append(reason) }
        if let partial = ck.partialErrorsByItemID, !partial.isEmpty {
            for (key, value) in partial {
                let name = (key as? CKRecord.ID)?.recordName ?? String(describing: key)
                if let inner = value as? CKError {
                    lines.append("\(name): CKError \(inner.errorCode) (\(inner.code))")
                } else {
                    lines.append("\(name): \(value.localizedDescription)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum SystemFieldsCache {
    private static let prefix = "ck.fields."

    static func store(_ record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        UserDefaults.standard.set(coder.encodedData, forKey: prefix + record.recordID.recordName)
    }

    static func remove(_ recordName: String) {
        UserDefaults.standard.removeObject(forKey: prefix + recordName)
    }

    static func record(id: CKRecord.ID) -> CKRecord {
        let key = prefix + id.recordName
        guard let data = UserDefaults.standard.data(forKey: key),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            return CKRecord(recordType: CloudConfig.recordType, recordID: id)
        }
        unarchiver.requiresSecureCoding = true
        let decoded = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        return decoded ?? CKRecord(recordType: CloudConfig.recordType, recordID: id)
    }
}

final class SyncDelegate: NSObject, CKSyncEngineDelegate, @unchecked Sendable {
    let scope: CKDatabase.Scope
    init(scope: CKDatabase.Scope) { self.scope = scope }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        let scope = self.scope
        await MainActor.run { SyncHub.shared.handle(event, scope: scope) }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        let records = await MainActor.run { SyncHub.shared.buildRecords(for: pending) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { id in
            records[id]
        }
    }
}
