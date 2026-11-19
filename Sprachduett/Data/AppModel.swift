import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var persisted: Persisted
    @Published var celebration: String?
    let catalog: ThaiCatalog

    init() {
        catalog = (try? CatalogLoader.loadBundled()) ?? ThaiCatalog(
            language: "th", title: "Thai", tones: [], topics: [], scenes: []
        )
        persisted = Persisted.load() ?? Persisted.fresh()
    }

    var onboarded: Bool { persisted.onboarded }
    var today: String { DayKey.string(from: Date(), calendar: Calendar.current) }
    var me: MemberProfile { persisted.member }
    var duo: DuoCloudState { persisted.duo }
    var myRole: DuettRole { persisted.myRole }

    var partner: MemberProfile? {
        persisted.duo.members.first { $0.id != persisted.learnerID }
    }

    var memberIDs: [String] { persisted.duo.members.map(\.id) }

    var streak: StreakStatus {
        StreakEngine.status(stamps: persisted.duo.stamps, members: memberIDs, today: today)
    }

    func points(for userID: String) -> Int {
        PointsLedger.total(
            userID: userID,
            confirmed: persisted.duo.confirmed,
            scenes: catalog.scenes,
            stamps: persisted.duo.stamps,
            members: memberIDs
        )
    }

    func progress(for scene: DuettScene) -> Int {
        let ids = Set(scene.lines.map(\.id))
        let done = Set(persisted.duo.confirmed.filter { $0.sceneID == scene.id }.map(\.lineID))
        return done.intersection(ids).count
    }

    func finishOnboarding(name: String, gender: SpeakerGender, emoji: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persisted.learnerName = trimmed.isEmpty ? "Ich" : trimmed
        persisted.learnerGender = gender
        persisted.learnerEmoji = emoji
        persisted.onboarded = true
        refreshMember()
        saveAndPush()
    }

    func updateProfile(name: String, gender: SpeakerGender, emoji: String) {
        persisted.learnerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persisted.learnerGender = gender
        persisted.learnerEmoji = emoji
        refreshMember()
        saveAndPush()
    }

    func adoptCloudUser(_ id: String) {
        guard persisted.learnerID != id else { return }
        let old = persisted.learnerID
        persisted.learnerID = id
        persisted.duo.members = persisted.duo.members.map { member in
            guard member.id == old else { return member }
            var copy = member
            copy.id = id
            return copy
        }
        persisted.duo.stamps = persisted.duo.stamps.map { stamp in
            stamp.userID == old ? PracticeStamp(userID: id, day: stamp.day) : stamp
        }
        persisted.duo.confirmed = persisted.duo.confirmed.map { line in
            guard line.userID == old else { return line }
            return ConfirmedLine(sceneID: line.sceneID, lineID: line.lineID, userID: id, day: line.day)
        }
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    func start(scene: DuettScene, passPhone: Bool) {
        persisted.duo.session = SessionSnapshot(
            sceneID: scene.id,
            cursor: 0,
            passedIDs: [],
            passPhone: passPhone,
            holder: .a,
            awaitingHandoff: passPhone,
            needsRepeat: false,
            updatedAt: Date()
        )
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    func turn(for scene: DuettScene) -> TurnView {
        guard let session = persisted.duo.session, session.sceneID == scene.id else {
            return TurnView(phase: .done, line: nil, showsThai: false)
        }
        return TurnEngine.view(scene: scene, snapshot: session, deviceRole: persisted.myRole)
    }

    func spoken(_ line: DuettLine) -> SpokenForm {
        Particles.apply(
            thai: line.thai,
            roman: line.roman,
            particle: line.particle,
            gender: gender(for: line.role)
        )
    }

    func confirmCurrent(in scene: DuettScene) {
        guard let session = persisted.duo.session, let line = TurnEngine.currentLine(scene: scene, snapshot: session) else { return }
        let speaker = persisted.duo.speakerID(for: line.role)
        let day = today
        let already = persisted.duo.confirmed.contains { item in
            item.sceneID == scene.id && item.lineID == line.id && item.userID == speaker
        }
        if !already {
            persisted.duo.confirmed.append(ConfirmedLine(sceneID: scene.id, lineID: line.id, userID: speaker, day: day))
        }
        let stamp = PracticeStamp(userID: speaker, day: day)
        if !persisted.duo.stamps.contains(stamp) {
            persisted.duo.stamps.append(stamp)
        }
        persisted.duo.session = TurnEngine.confirm(session, scene: scene, lineID: line.id, at: Date())
        persisted.duo.updatedAt = Date()
        saveAndPush()
        noteStreak()
        Haptics.success()
    }

    func acceptHandoff(in scene: DuettScene) {
        guard let session = persisted.duo.session else { return }
        persisted.duo.session = TurnEngine.acceptHandoff(session, scene: scene, at: Date())
        persisted.duo.updatedAt = Date()
        saveAndPush()
        Haptics.tap()
    }

    func requestRepeat() {
        guard let session = persisted.duo.session else { return }
        persisted.duo.session = TurnEngine.requestRepeat(session, at: Date())
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    func rewind(in scene: DuettScene) {
        guard let session = persisted.duo.session else { return }
        persisted.duo.session = TurnEngine.rewind(session, scene: scene, at: Date())
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    var needsRepeat: Bool { persisted.duo.session?.needsRepeat ?? false }

    func beginSharing() {
        persisted.sharingStarted = true
        persisted.isSharedZone = false
        persisted.duo.updatedAt = Date()
        refreshMember()
        persisted.save()
    }

    func noteSharedZone(ownerName: String, duoID: String) {
        persisted.isSharedZone = true
        persisted.sharingStarted = true
        persisted.zoneOwnerName = ownerName
        if persisted.duo.duoID != duoID {
            persisted.duo.duoID = duoID
            persisted.duo.updatedAt = .distantPast
        }
        persisted.save()
    }

    /// Liefert true, wenn der lokale Stand etwas hat, das zurückgeschickt werden muss.
    @discardableResult
    func applyRemote(_ remote: DuoCloudState) -> Bool {
        guard persisted.sharingStarted || persisted.isSharedZone else { return false }
        if persisted.duo.duoID != remote.duoID {
            var state = remote
            let mine = persisted.member
            if !state.members.contains(where: { $0.id == mine.id }) {
                var copy = mine
                let taken = Set(state.members.map(\.role))
                copy.role = taken.contains(.b) ? .a : .b
                state.members.append(copy)
                persisted.myRole = copy.role
                state.updatedAt = Date()
                persisted.duo = state
                save()
                noteStreak()
                return true
            }
            persisted.myRole = state.members.first { $0.id == mine.id }?.role ?? .b
            persisted.duo = state
            save()
            noteStreak()
            return false
        }
        let merged = DuoMerge.merge(persisted.duo, remote)
        persisted.duo = merged
        if let mine = merged.members.first(where: { $0.id == persisted.learnerID }) {
            persisted.myRole = mine.role
            persisted.learnerName = mine.name
            persisted.learnerGender = mine.gender
            persisted.learnerEmoji = mine.emoji
        }
        save()
        noteStreak()
        return merged != remote
    }

    func swapRoles() {
        guard persisted.duo.members.count >= 2 else { return }
        persisted.duo.members = persisted.duo.members.map { member in
            var copy = member
            copy.role = member.role.other
            return copy
        }
        persisted.myRole = persisted.myRole.other
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    func dismissCelebration() {
        celebration = nil
    }

    private func gender(for role: DuettRole) -> SpeakerGender {
        persisted.duo.member(for: role)?.gender ?? persisted.learnerGender
    }

    private func refreshMember() {
        var members = persisted.duo.members.filter { $0.id != persisted.learnerID }
        members.append(persisted.member)
        persisted.duo.members = members
        persisted.duo.updatedAt = Date()
    }

    private func noteStreak() {
        let status = streak
        guard status.todayBoth, status.length > persisted.celebratedLength else { return }
        persisted.celebratedLength = status.length
        if memberIDs.count >= 2 {
            celebration = status.length == 1 ? "Euer erster gemeinsamer Tag" : "\(status.length) Tage zusammen"
        } else {
            celebration = status.length == 1 ? "Erster Übungstag" : "\(status.length) Tage am Stück"
        }
        save()
    }

    private func saveAndPush() {
        save()
        SyncHub.shared.push()
    }

    private func save() {
        persisted.save()
    }
}

struct Persisted: Codable, Equatable {
    var onboarded: Bool
    var learnerID: String
    var learnerName: String
    var learnerGender: SpeakerGender
    var learnerEmoji: String
    var myRole: DuettRole
    var duo: DuoCloudState
    var isSharedZone: Bool
    var zoneOwnerName: String
    var sharingStarted: Bool
    var celebratedLength: Int

    var member: MemberProfile {
        MemberProfile(
            id: learnerID,
            name: learnerName,
            gender: learnerGender,
            emoji: learnerEmoji,
            role: myRole
        )
    }

    static func fresh() -> Persisted {
        let id = "local"
        let duo = DuoCloudState(
            duoID: UUID().uuidString,
            title: "Unser Duett",
            members: [MemberProfile(id: id, name: "", gender: .unspecified, emoji: "🐘", role: .a)],
            stamps: [],
            confirmed: [],
            session: nil,
            updatedAt: Date()
        )
        return Persisted(
            onboarded: false,
            learnerID: id,
            learnerName: "",
            learnerGender: .unspecified,
            learnerEmoji: "🐘",
            myRole: .a,
            duo: duo,
            isSharedZone: false,
            zoneOwnerName: "",
            sharingStarted: false,
            celebratedLength: 0
        )
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Sprachduett", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("state.json")
    }

    static func load() -> Persisted? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Persisted.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
