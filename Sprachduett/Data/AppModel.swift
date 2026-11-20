import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var persisted: Persisted
    @Published var celebration: String?
    @Published var launchSolo = false
    @Published var pausedRound: SavedRound?
    let language: ThaiLanguage
    let catalog: ThaiCatalog

    init() {
        let loaded = (try? CatalogLoader.loadBundled()) ?? ThaiCatalog(
            language: "th", title: "Thai", tones: [], topics: [], scenes: []
        )
        let pack = ContentPacks.loadThai(catalog: loaded)
        language = pack.language
        catalog = pack.catalog
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

    var partnerSeatName: String {
        let trimmed = persisted.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Partner" : trimmed
    }

    var persistedPartnerGender: SpeakerGender { persisted.partnerGender }

    func updateSeats(name: String, gender: SpeakerGender, partnerName: String, partnerGender: SpeakerGender) {
        persisted.learnerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persisted.learnerGender = gender
        persisted.partnerName = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        persisted.partnerGender = partnerGender
        refreshMember()
        saveAndPush()
    }

    func gender(forSpeaker speakerID: String, partnerID: String) -> SpeakerGender {
        let right = speakerID == "p2" || speakerID == partnerID
        if right {
            if let partner, partner.id == speakerID, partner.gender != .unspecified {
                return partner.gender
            }
            return persisted.partnerGender
        }
        return persisted.learnerGender
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
                materializeVoices()
                return true
            }
            persisted.myRole = state.members.first { $0.id == mine.id }?.role ?? .b
            persisted.duo = state
            save()
            noteStreak()
            materializeVoices()
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
        materializeVoices()
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

    var pathUnits: [LearnUnit] { LearningPath.load(from: catalog) }

    var pathStats: [String: WordStat] {
        Dictionary(persisted.wordStats.map { ($0.id, $0) }, uniquingKeysWith: { _, next in next })
    }

    var pathSnapshot: PathSnapshot {
        LearningPath.snapshot(units: pathUnits, stats: pathStats)
    }

    var checkedStages: Set<Int> { Set(persisted.checks.map(\.level)) }

    var stars: Int { pathStats.values.reduce(0) { $0 + $1.correct } }

    var practicedDayKeys: Set<String> { Set(persisted.duo.stamps.map(\.day)) }

    var persistedChecks: [CheckRecord] { persisted.checks }

    var usageLine: String {
        let usage = persisted.usage
        let average = usage.averageSeconds.map { "\(Int($0)) s" } ?? "–"
        return "Runden \(usage.roundsStarted), fertig \(usage.roundsFinished), abgebrochen \(usage.abandoned), Dauer \(average). Nur auf diesem Gerät."
    }

    var partnerConnected: Bool {
        guard partner != nil else { return false }
        switch SyncHub.shared.status {
        case .idle, .syncing: return true
        default: return false
        }
    }

    var persistedUsage: UsageLog { persisted.usage }

    var ownCards: [OwnCard] { persisted.ownCards }

    var ownWords: [PathWord] {
        persisted.ownCards.map { PathWord(id: $0.id, emoji: "✏️", thai: $0.thai, roman: $0.roman.isEmpty ? $0.thai : $0.roman, german: $0.german) }
    }

    var phraseHits: [PhraseHit] {
        catalog.phrases.map { PhraseHit(id: $0.id, thai: $0.thai, roman: $0.roman, german: $0.german) }
    }

    var dailyWord: PhraseHit? {
        let hits = phraseHits
        guard !hits.isEmpty else { return nil }
        return hits[WordOfDay.index(day: today, count: hits.count)]
    }

    var scriptUnlocked: Int {
        ScriptCourse.unlockedCount(done: persisted.scriptDone, lastDay: persisted.scriptDay, today: today)
    }

    var canFinishScript: Bool {
        persisted.scriptDone < scriptUnlocked
    }

    func completeScriptLesson() {
        guard canFinishScript else { return }
        persisted.scriptDone += 1
        persisted.scriptDay = today
        save()
    }

    func addOwn(_ card: OwnCard) {
        persisted.ownCards.removeAll { $0.id == card.id }
        persisted.ownCards.append(card)
        save()
    }

    func audioFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Sprachduett/OwnAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func audioURL(named name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let url = audioFolder().appendingPathComponent("\(name).m4a")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func refreshNudge() {
        let stamps = persisted.duo.stamps.map { ($0.userID, $0.day) }
        let fire = CoupleReminder.shouldNudge(myID: me.id, partnerID: partner?.id, stamps: stamps, today: today)
        CoupleNudge.schedule(fire)
    }

    var headline: String {
        persisted.checks.max { $0.date < $1.date }?.sentence
            ?? "Noch kein Alltags-Check. Der kommt, wenn eine Stufe sitzt."
    }

    func dueCheckLevel() -> Int? {
        let stages = [2, 1]
        for stage in stages {
            let units = pathUnits.filter { $0.stage == stage }
            let mastered = !units.isEmpty && units.allSatisfy { LearningPath.ratio($0, stats: pathStats) >= LearningPath.unlockRatio }
            let last = persisted.checks.filter { $0.level == stage }.map(\.date).max()
            if RealLifeCheck.isDue(stageMastered: mastered, last: last, now: Date()) { return stage }
        }
        return nil
    }

    func saveCheck(_ record: CheckRecord) {
        persisted.checks.append(record)
        save()
        if record.level >= 2 { noteQuest(check: true) }
    }

    var hideRoman: Bool { persisted.hideRoman }

    func setHideRoman(_ hidden: Bool) {
        persisted.hideRoman = hidden
        save()
    }

    var quest: QuestProgress {
        QuestProgress(rounds: persisted.questRounds, checks: persisted.questChecks, celebrated: persisted.questCelebrated)
    }

    func refreshQuestWeek() {
        let key = PairQuest.weekKey(Date())
        guard persisted.questWeek != key else { return }
        persisted.questWeek = key
        persisted.questRounds = 0
        persisted.questChecks = 0
        persisted.questCelebrated = false
        save()
    }

    func noteQuest(round: Bool = false, check: Bool = false) {
        refreshQuestWeek()
        let before = quest.done
        let next = PairQuest.record(
            rounds: persisted.questRounds,
            checks: persisted.questChecks,
            celebrated: persisted.questCelebrated,
            addRound: round,
            addCheck: check
        )
        persisted.questRounds = next.rounds
        persisted.questChecks = next.checks
        if next.done, !before, !next.celebrated {
            persisted.questCelebrated = true
            celebration = "Paar-Quest geschafft"
            Haptics.success()
        }
        save()
    }

    func voiceFile(wordID: String, ownerID: String) -> URL {
        audioFolder().appendingPathComponent("voice-\(ownerID)-\(wordID).m4a")
    }

    func saveVoice(wordID: String, ownerID: String, data: Data) {
        let url = voiceFile(wordID: wordID, ownerID: ownerID)
        try? data.write(to: url, options: .atomic)
        let clip = VoiceClip(wordID: wordID, ownerID: ownerID, updatedAt: Date(), audioBase64: data.base64EncodedString())
        persisted.duo.voiceClips = VoiceLibrary.merge(persisted.duo.voiceClips, [clip])
        persisted.duo.updatedAt = Date()
        saveAndPush()
    }

    func partnerVoiceURL(wordID: String) -> URL? {
        materializeVoices()
        let owners = [partner?.id, "p2", "p1", me.id].compactMap { $0 }
        for owner in owners {
            let url = voiceFile(wordID: wordID, ownerID: owner)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func materializeVoices() {
        for clip in persisted.duo.voiceClips {
            let url = voiceFile(wordID: clip.wordID, ownerID: clip.ownerID)
            if FileManager.default.fileExists(atPath: url.path) { continue }
            guard let data = Data(base64Encoded: clip.audioBase64), !data.isEmpty else { continue }
            try? data.write(to: url, options: .atomic)
        }
    }

    func noteRoundStarted() {
        persisted.usage = persisted.usage.started()
        save()
    }

    func noteRoundFinished(seconds: Double) {
        persisted.usage = persisted.usage.finished(seconds: seconds)
        save()
    }

    func noteAbandoned(game: String) {
        persisted.usage = persisted.usage.abandoned(game: game)
        save()
    }

    func addFeedback(screen: String, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        persisted.feedback.append(FeedbackNote(id: UUID().uuidString, date: Date(), screen: screen, note: trimmed))
        save()
    }

    var hasFeedback: Bool { !persisted.feedback.isEmpty }

    var feedbackExport: String {
        if persisted.feedback.isEmpty { return "Noch keine Notizen." }
        return persisted.feedback.map(\.exportLine).joined(separator: "\n")
    }

    func pauseRound(_ round: SavedRound) {
        pausedRound = round
    }

    func clearPausedRound() {
        pausedRound = nil
    }

    func rememberRound(_ stats: [String: WordStat], together: Bool) {
        pausedRound = nil
        var map = pathStats
        for (key, value) in stats { map[key] = value }
        persisted.wordStats = map.values.sorted { $0.id < $1.id }
        let day = today
        var ids = [me.id]
        if together, let partner { ids.append(partner.id) }
        for id in ids {
            let stamp = PracticeStamp(userID: id, day: day)
            if !persisted.duo.stamps.contains(stamp) { persisted.duo.stamps.append(stamp) }
        }
        persisted.duo.updatedAt = Date()
        saveAndPush()
        noteStreak()
        refreshNudge()
        if together { noteQuest(round: true) }
    }

    func publishClaim(itemID: String, playerID: String, choiceID: String) {
        persisted.duo.liveClaim = LiveClaim(itemID: itemID, playerID: playerID, choiceID: choiceID, at: Date())
        persisted.duo.updatedAt = Date()
        saveAndPush()
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
    var partnerName: String
    var partnerGender: SpeakerGender
    var myRole: DuettRole
    var duo: DuoCloudState
    var isSharedZone: Bool
    var zoneOwnerName: String
    var sharingStarted: Bool
    var celebratedLength: Int
    var wordStats: [WordStat]
    var usage: UsageLog
    var feedback: [FeedbackNote]
    var checks: [CheckRecord]
    var ownCards: [OwnCard]
    var scriptDone: Int
    var scriptDay: String
    var questWeek: String
    var questRounds: Int
    var questChecks: Int
    var questCelebrated: Bool
    var hideRoman: Bool

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
            partnerName: "Partner",
            partnerGender: .unspecified,
            myRole: .a,
            duo: duo,
            isSharedZone: false,
            zoneOwnerName: "",
            sharingStarted: false,
            celebratedLength: 0,
            wordStats: [],
            usage: UsageLog(),
            feedback: [],
            checks: [],
            ownCards: [],
            scriptDone: 0,
            scriptDay: "",
            questWeek: "",
            questRounds: 0,
            questChecks: 0,
            questCelebrated: false,
            hideRoman: false
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
        let decoder = JSONDecoder()
        if let full = try? decoder.decode(Persisted.self, from: patched(data)) { return full }
        guard let legacy = try? decoder.decode(LegacyPersisted.self, from: data) else { return nil }
        return legacy.upgraded()
    }

    private static func patched(_ data: Data) -> Data {
        guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        if object["wordStats"] == nil { object["wordStats"] = [] }
        if object["usage"] == nil {
            object["usage"] = ["roundsStarted": 0, "roundsFinished": 0, "totalSeconds": 0, "abandonedByGame": [:]] as [String: Any]
        }
        if object["feedback"] == nil { object["feedback"] = [] }
        if object["checks"] == nil { object["checks"] = [] }
        if object["partnerName"] == nil { object["partnerName"] = "Partner" }
        if object["partnerGender"] == nil { object["partnerGender"] = "unspecified" }
        if object["ownCards"] == nil { object["ownCards"] = [] }
        if object["scriptDone"] == nil { object["scriptDone"] = 0 }
        if object["scriptDay"] == nil { object["scriptDay"] = "" }
        if object["questWeek"] == nil { object["questWeek"] = "" }
        if object["questRounds"] == nil { object["questRounds"] = 0 }
        if object["questChecks"] == nil { object["questChecks"] = 0 }
        if object["questCelebrated"] == nil { object["questCelebrated"] = false }
        if object["hideRoman"] == nil { object["hideRoman"] = false }
        return (try? JSONSerialization.data(withJSONObject: object)) ?? data
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

private struct LegacyPersisted: Codable {
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

    func upgraded() -> Persisted {
        Persisted(
            onboarded: onboarded,
            learnerID: learnerID,
            learnerName: learnerName,
            learnerGender: learnerGender,
            learnerEmoji: learnerEmoji,
            partnerName: "Partner",
            partnerGender: .unspecified,
            myRole: myRole,
            duo: duo,
            isSharedZone: isSharedZone,
            zoneOwnerName: zoneOwnerName,
            sharingStarted: sharingStarted,
            celebratedLength: celebratedLength,
            wordStats: [],
            usage: UsageLog(),
            feedback: [],
            checks: [],
            ownCards: [],
            scriptDone: 0,
            scriptDay: "",
            questWeek: "",
            questRounds: 0,
            questChecks: 0,
            questCelebrated: false,
            hideRoman: false
        )
    }
}
