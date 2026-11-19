import SwiftUI

@MainActor
final class RoundController: ObservableObject {
    @Published private(set) var plan = RoundPlan(beats: [], label: "", unitTitle: "")
    @Published private(set) var cursor = RoundCursor()
    @Published var coach: GuideCard?
    @Published private(set) var mode: PlayMode = .togetherOnePhone
    @Published private(set) var leftName = "Du"
    @Published private(set) var rightName = "Partner"
    private var stats: [String: WordStat] = [:]
    private var hinted = Set<String>()
    private var localID = "p1"
    private var partnerID = "p2"
    private var showCoach = false
    var onFinish: (([WordStat]) -> Void)?
    var onClaim: ((String, String, String) -> Void)?

    var beat: Beat? { RoundEngine.beat(plan, cursor) }
    var done: Bool { cursor.finished }

    var instruction: String {
        switch beat {
        case .intro(_): return "Hör zu und sprecht nach."
        case .listen(_): return "Wer tippt zuerst richtig?"
        case .say(_) where cursor.phase == .speak: return "Sag das Thai-Wort laut."
        case .say(_): return "War es richtig?"
        case .dialog(_): return "Lies deinen Satz laut vor."
        case nil: return "Geschafft."
        }
    }

    var turnName: String {
        switch beat {
        case .intro(_), .listen(_), nil:
            return mode == .solo ? leftName : "\(leftName)  ·  \(rightName)"
        case .say(let turn): return display(turn.speakerID)
        case .dialog(let turn): return display(turn.speakerID)
        }
    }

    var turnIsLeft: Bool {
        switch beat {
        case .say(let turn): return turn.speakerID != "p2" && turn.speakerID != partnerID
        case .dialog(let turn): return turn.speakerID != "p2" && turn.speakerID != partnerID
        default: return true
        }
    }

    func points(left: Bool) -> Int {
        if left {
            return cursor.scores["p1", default: 0] + cursor.scores[localID, default: 0]
        }
        return cursor.scores["p2", default: 0] + cursor.scores[partnerID, default: 0]
    }

    func display(_ id: String) -> String {
        if id == "p2" || id == partnerID { return rightName }
        return leftName
    }

    func snapshot(together: Bool) -> SavedRound {
        SavedRound(
            together: together,
            plan: plan,
            cursor: cursor,
            stats: Array(stats.values),
            leftName: leftName,
            rightName: rightName,
            mode: mode,
            localID: localID,
            partnerID: partnerID,
            showCoach: showCoach
        )
    }

    func restore(_ saved: SavedRound) {
        plan = saved.plan
        cursor = saved.cursor
        stats = Dictionary(saved.stats.map { ($0.id, $0) }, uniquingKeysWith: { _, next in next })
        leftName = saved.leftName
        rightName = saved.rightName
        mode = saved.mode
        localID = saved.localID
        partnerID = saved.partnerID
        showCoach = saved.showCoach
        coach = nil
        presentCoachIfNeeded()
    }

    func start(units: [LearnUnit], stats: [String: WordStat], together: Bool, partnerConnected: Bool,
               left: String, right: String, localID: String, partnerID: String, coach: Bool) {
        self.stats = stats
        self.localID = localID
        self.partnerID = partnerID
        showCoach = coach
        hinted = []
        mode = PlayMode.resolve(together: together, partnerConnected: partnerConnected)
        leftName = left
        rightName = right
        cursor = RoundCursor()
        plan = RoundBuilder.build(
            units: units, stats: stats,
            seed: UInt64(Date().timeIntervalSince1970),
            together: mode != .solo
        )
        self.coach = nil
        presentCoachIfNeeded()
    }

    func dismissCoach() {
        guard let coach else { return }
        hinted.insert(coach.id)
        self.coach = nil
    }

    func nextIntro() { move(RoundEngine.advance(cursor, plan: plan), nil) }

    func tap(player: String, choice: String) {
        guard case .listen(let item)? = beat else { return }
        let who = mode == .twoPhones ? localID : player
        let seats = listenSeats
        let (next, grade) = RoundEngine.listenTap(cursor, plan: plan, playerID: who, choiceID: choice, seats: seats)
        if mode == .twoPhones { onClaim?(item.id, who, choice) }
        move(next, grade)
    }

    func applyRemote(itemID: String, player: String, choice: String) {
        guard mode == .twoPhones, case .listen(let item) = beat, item.id == itemID, player != localID else { return }
        let (next, grade) = RoundEngine.listenTap(cursor, plan: plan, playerID: player, choiceID: choice, seats: [localID, player])
        move(next, grade)
    }

    func saidIt() { cursor = RoundEngine.revealSay(cursor, plan: plan) }
    func judged(_ correct: Bool) {
        let (next, grade) = RoundEngine.judgeSay(cursor, plan: plan, correct: correct)
        move(next, grade)
    }
    func finishSpeech(_ grade: SpeechGrade, wordID: String?, speakerID: String) {
        if let wordID { stats = RoundEngine.applySpeech(stats, wordID: wordID, grade: grade) }
        var next = cursor
        if grade == .sure { next.scores[speakerID, default: 0] += 1 }
        next = RoundEngine.advance(next, plan: plan)
        move(next, nil)
    }

    var gameName: String {
        switch beat {
        case .intro(_): return "intro"
        case .listen(_): return "listen"
        case .say(_): return "say"
        case .dialog(_): return "dialog"
        case nil: return "results"
        }
    }

    func understood() { move(RoundEngine.confirmDialog(cursor, plan: plan), nil) }

    private var listenSeats: [String] {
        switch mode {
        case .solo: return ["p1"]
        case .togetherOnePhone: return ["p1", "p2"]
        case .twoPhones: return [localID, partnerID]
        }
    }

    private func move(_ next: RoundCursor, _ grade: GradedWord?) {
        cursor = next
        if let grade { stats = RoundEngine.apply(stats, grade) }
        presentCoachIfNeeded()
        if cursor.finished { onFinish?(Array(stats.values)) }
    }

    private func presentCoachIfNeeded() {
        guard showCoach, coach == nil, let beat else { return }
        let key: String
        switch beat {
        case .intro(_): key = "intro"
        case .listen(_): key = "listen"
        case .say(_): key = "say"
        case .dialog(_): key = "dialog"
        }
        guard !hinted.contains(key), let card = LessonTour.steps.first(where: { $0.id == key }) else { return }
        coach = card
    }
}

struct SavedRound: Equatable {
    var together: Bool
    var plan: RoundPlan
    var cursor: RoundCursor
    var stats: [WordStat]
    var leftName: String
    var rightName: String
    var mode: PlayMode
    var localID: String
    var partnerID: String
    var showCoach: Bool
}

struct RoundScreen: View {
    let together: Bool
    var resume: Bool = false
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechCoach
    @EnvironmentObject private var screens: ScreenTracker
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var started = Date()
    @State private var closed = false
    @State private var confirmLeave = false
    @StateObject private var round = RoundController()

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                CloseBar {
                    if round.done {
                        closed = true
                        dismiss()
                    } else {
                        confirmLeave = true
                    }
                }
                TurnBanner(name: round.turnName, left: round.turnIsLeft, text: round.instruction)
                if round.done {
                    ResultsPane(
                        leftName: round.leftName,
                        rightName: round.rightName,
                        leftPoints: round.points(left: true),
                        rightPoints: round.points(left: false),
                        solo: round.mode == .solo,
                        streak: model.streak.length,
                        again: { dismiss() }
                    )
                } else {
                    beatBody
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .overlay {
            if let card = round.coach {
                LessonCoach(step: LessonTour.steps.firstIndex { $0.id == card.id } ?? 0) {
                    round.dismissCoach()
                }
            }
        }
        .onAppear {
            screens.name = "Runde"
            started = Date()
            model.noteRoundStarted()
            boot()
        }
        .onDisappear {
            guard !closed, !round.done else { return }
            model.pauseRound(round.snapshot(together: together))
        }
        .alert("Runde pausieren?", isPresented: $confirmLeave) {
            Button("Pausieren") { leave() }
            Button("Weiter spielen", role: .cancel) {}
        } message: {
            Text("Zusammen spielen bietet danach Weiterspielen an.")
        }
        .background(SwipeBackEnabler())
        .navigationBarBackButtonHidden(true)
        .onChange(of: model.duo.liveClaim?.at) { _, _ in
            guard let claim = model.duo.liveClaim else { return }
            round.applyRemote(itemID: claim.itemID, player: claim.playerID, choice: claim.choiceID)
        }
    }

    @ViewBuilder private var beatBody: some View {
        switch round.beat {
        case .intro(let word):
            IntroPane(word: word, speak: { speech.speak(word.thai) }, slow: { speech.speak(word.thai, slow: true) }, next: round.nextIntro)
        case .listen(let item):
            ListenBoard(item: item, mode: round.mode, left: round.leftName, right: round.rightName) { player, choice in
                round.tap(player: player, choice: choice)
            }
        case .say(let turn):
            let form = voiced(thai: turn.word.thai, roman: turn.word.roman, speakerID: turn.speakerID, dialog: false)
            SpeechCard(
                emoji: turn.word.emoji,
                thai: form.thai,
                roman: form.roman,
                german: turn.word.german,
                alternates: [turn.word.thai],
                hideThaiUntilGraded: true,
                romanOpacity: romanOpacity(wordID: turn.word.id),
                speech: speech,
                onGrade: { grade in round.finishSpeech(grade, wordID: turn.word.id, speakerID: turn.speakerID) }
            )
            .id(turn.id)
        case .dialog(let turn):
            let form = voiced(thai: turn.line.thai, roman: turn.line.roman, speakerID: turn.speakerID, dialog: true)
            SpeechCard(
                emoji: "💬",
                thai: form.thai,
                roman: form.roman,
                german: turn.line.german,
                alternates: [turn.line.thai],
                hideThaiUntilGraded: false,
                romanOpacity: 1,
                speech: speech,
                onGrade: { grade in round.finishSpeech(grade, wordID: nil, speakerID: turn.speakerID) }
            )
            .id(turn.id)
        case nil:
            EmptyView()
        }
    }

    private func leave() {
        closed = true
        if !round.done {
            model.pauseRound(round.snapshot(together: together))
        }
        dismiss()
    }

    private func boot() {
        round.onFinish = { stats in
            lessonSeen = true
            let playedTogether = together && round.mode != .solo
            closed = true
            model.noteRoundFinished(seconds: Date().timeIntervalSince(started))
            model.rememberRound(Dictionary(stats.map { ($0.id, $0) }, uniquingKeysWith: { _, next in next }), together: playedTogether)
        }
        round.onClaim = { item, player, choice in
            model.publishClaim(itemID: item, playerID: player, choiceID: choice)
        }
        if resume, let saved = model.pausedRound {
            round.restore(saved)
            return
        }
        model.clearPausedRound()
        round.start(
            units: model.pathUnits,
            stats: model.pathStats,
            together: together,
            partnerConnected: model.partnerConnected,
            left: model.me.name.isEmpty ? "Du" : model.me.name,
            right: model.partner?.name ?? model.partnerSeatName,
            localID: model.me.id,
            partnerID: model.partner?.id ?? "p2",
            coach: !lessonSeen
        )
    }

    private func voiced(thai: String, roman: String, speakerID: String, dialog: Bool) -> SpokenForm {
        let gender = model.gender(forSpeaker: speakerID, partnerID: model.partner?.id ?? "p2")
        return GenderVoice.speak(
            thai: thai,
            roman: roman,
            gender: gender,
            polite: GenderVoice.usesParticle(thai, dialog: dialog)
        )
    }

    private func romanOpacity(wordID: String) -> Double {
        let stat = model.pathStats[wordID]
        return RomanFade.opacity(reviews: stat?.reviews ?? 0, pronunciation: stat?.pronunciation ?? 0)
    }
}

private struct TurnBanner: View {
    let name: String
    let left: Bool
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .minimumScaleFactor(0.6)
                .foregroundStyle(left ? Theme.navy : Theme.accent)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct IntroPane: View {
    let word: PathWord
    let speak: () -> Void
    let slow: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(word.emoji).font(.system(size: 88))
            ToneLine(roman: word.roman)
            Text(word.german).font(.title2)
            FillButton(title: "Anhören", systemImage: "speaker.wave.2", action: speak)
            FillButton(title: "Langsam", systemImage: "tortoise", action: slow)
            FillButton(title: "Weiter", action: next)
        }
    }
}

private struct ListenBoard: View {
    let item: ListenChallenge
    let mode: PlayMode
    let left: String
    let right: String
    let tap: (String, String) -> Void

    var body: some View {
        if mode == .togetherOnePhone {
            HStack(alignment: .top, spacing: 8) {
                choiceColumn(title: left, player: "p1", color: Theme.navy)
                choiceColumn(title: right, player: "p2", color: Theme.accent)
            }
        } else {
            choiceColumn(title: "", player: "p1", color: Theme.navy)
        }
    }

    private func choiceColumn(title: String, player: String, color: Color) -> some View {
        VStack(spacing: 8) {
            if !title.isEmpty {
                Text(title).font(.headline).foregroundStyle(color)
            }
            ForEach(item.choices) { choice in
                Button {
                    tap(player, choice.id)
                } label: {
                    Text(choice.emoji)
                        .font(.system(size: 36))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SpeechCard: View {
    let emoji: String
    let thai: String
    let roman: String
    let german: String
    var alternates: [String] = []
    let hideThaiUntilGraded: Bool
    var romanOpacity: Double = 1
    let speech: SpeechCoach
    let onGrade: (SpeechGrade) -> Void
    @State private var grade: SpeechGrade?
    @State private var fallback = false

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 72))
            Text(german).font(.title3)
            SpeechListenDeck(
                thai: thai,
                roman: roman,
                alternates: alternates,
                romanOpacity: romanOpacity,
                speech: speech,
                grade: $grade,
                fallback: $fallback,
                hidesThaiUntilListening: hideThaiUntilGraded
            )
            FillButton(title: "Nochmal anhören", systemImage: "tortoise") { speech.speak(thai, slow: true) }
            if let grade {
                FillButton(title: "Weiter") { onGrade(grade) }
            }
        }
    }
}

private struct ResultsPane: View {
    let leftName: String
    let rightName: String
    let leftPoints: Int
    let rightPoints: Int
    let solo: Bool
    let streak: Int
    let again: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("🎉").font(.system(size: 64))
            Text("Runde geschafft").font(.title.weight(.bold))
            Text("\(leftName): \(leftPoints)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.navy)
            if !solo {
                Text("\(rightName): \(rightPoints)")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            Text("Serie: \(streak)")
                .foregroundStyle(.secondary)
            FillButton(title: "Nochmal", action: again)
        }
    }
}

struct ToneLine: View {
    let roman: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RomanTones.syllables(roman)) { piece in
                VStack(spacing: 2) {
                    Text(piece.tone.arrow).font(.caption.weight(.bold)).foregroundStyle(color(piece.tone))
                    Text(piece.text).font(.title3.weight(.semibold)).foregroundStyle(color(piece.tone))
                }
            }
        }
    }

    private func color(_ tone: ToneColor) -> Color {
        switch tone {
        case .mid: return .primary
        case .low: return Color(red: 0.20, green: 0.45, blue: 0.75)
        case .falling: return Theme.brick
        case .high: return Theme.accent
        case .rising: return Theme.sage
        }
    }
}
