import AudioToolbox
import AVFoundation
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

    var lessonProgress: Double {
        let total = max(plan.beats.count, 1)
        if cursor.finished { return 1 }
        return Double(min(max(cursor.index, 0), total)) / Double(total)
    }

    var bannerTitle: String {
        switch beat {
        case .listen(let item):
            switch cursor.listenPhase {
            case .speak: return "\(display(item.speakerID)): sag das Wort!"
            case .point: return "\(display(item.listenerID)): zeig das passende Bild!"
            case .handoff: return item.speakerID == item.listenerID ? "Jetzt das Bild" : "Handy weitergeben"
            case .result:
                if cursor.speechUnderstood && cursor.pictureRight { return "Punkt für beide" }
                if !cursor.speechUnderstood { return "Kein Punkt: das Wort kam nicht an" }
                return "Kein Punkt: das Bild war ein anderes"
            case .explain, .pending:
                return "Hör & Zeig"
            }
        case .say(let turn): return display(turn.speakerID)
        case .dialog(let turn): return display(turn.speakerID)
        case .build: return "Gemeinsam bauen"
        case .intro, nil:
            return mode == .solo ? leftName : "\(leftName)  ·  \(rightName)"
        }
    }

    var bannerDetail: String {
        switch beat {
        case .intro: return "Hör zu und sprecht nach."
        case .listen where cursor.listenPhase == .explain || cursor.listenPhase == .pending:
            return "Eine Person sagt das Wort, die andere hört nur zu und tippt das Bild, und den Punkt gibt es nur für beide zusammen."
        case .listen where cursor.listenPhase == .handoff && (beatSpeaker == beatListener):
            return "Schau nicht noch einmal auf das Wort."
        case .listen where cursor.listenPhase == .handoff:
            return "\(display(beatListener)) hört nur zu. Das Wort nicht zeigen."
        case .say where cursor.phase == .speak: return "Sag das Thai-Wort laut."
        case .say: return "War es richtig?"
        case .dialog: return "Lies deinen Satz laut vor."
        case .build: return "Jeder legt seine Hälfte in die richtige Reihenfolge. Der Punkt gilt nur für beide."
        case nil: return "Geschafft."
        default: return ""
        }
    }

    var turnIsLeft: Bool {
        let id: String
        switch beat {
        case .listen(let item):
            id = cursor.listenPhase == .point || cursor.listenPhase == .handoff ? item.listenerID : item.speakerID
        case .say(let turn): id = turn.speakerID
        case .dialog(let turn): id = turn.speakerID
        case .build: return true
        default: return true
        }
        return id != "p2" && id != partnerID
    }

    private var beatListener: String {
        if case .listen(let item) = beat { return item.listenerID }
        return "p2"
    }

    private var beatSpeaker: String {
        if case .listen(let item) = beat { return item.speakerID }
        return "p1"
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
        cursor = RoundEngine.prepare(cursor, plan: plan)
        coach = nil
        presentCoachIfNeeded()
    }

    func start(units: [LearnUnit], stats: [String: WordStat], together: Bool, partnerConnected: Bool,
               left: String, right: String, localID: String, partnerID: String, coach: Bool, extras: [PathWord] = []) {
        self.stats = stats
        self.localID = localID
        self.partnerID = partnerID
        showCoach = coach
        hinted = []
        mode = PlayMode.resolve(together: together, partnerConnected: partnerConnected)
        leftName = left
        rightName = right
        plan = RoundBuilder.build(
            units: units, stats: stats,
            seed: UInt64(Date().timeIntervalSince1970),
            together: mode != .solo,
            extras: extras
        )
        cursor = RoundEngine.prepare(RoundCursor(), plan: plan)
        self.coach = nil
        presentCoachIfNeeded()
    }

    func dismissCoach() {
        guard let coach else { return }
        hinted.insert(coach.id)
        self.coach = nil
    }

    func nextIntro() { move(RoundEngine.advance(cursor, plan: plan), nil) }

    func acceptExplain() {
        cursor = RoundEngine.beginSpeaking(cursor, plan: plan)
    }

    func noteListenSpeech(_ grade: SpeechGrade) {
        if case .listen(let item) = beat {
            stats = RoundEngine.applySpeech(stats, wordID: item.answer.id, grade: grade)
        }
        cursor = RoundEngine.noteSpeech(cursor, plan: plan, understood: grade != .miss)
    }

    func confirmHandoff() {
        cursor = RoundEngine.confirmHandoff(cursor, plan: plan)
    }

    func choosePicture(_ choice: String) {
        let understood = cursor.speechUnderstood
        let (next, grade) = RoundEngine.point(cursor, plan: plan, choiceID: choice)
        move(next, grade)
        if understood && next.pictureRight { Haptics.success() } else { Haptics.warning() }
    }

    func finishListen() {
        move(RoundEngine.advance(cursor, plan: plan), nil)
    }

    func tapBuild(_ token: Int) {
        guard case .build(let item) = beat else { return }
        guard let placed = BuildEngine.place(cursor.buildPlaced, token: token) else {
            Haptics.warning()
            return
        }
        cursor.buildPlaced = placed
        guard BuildEngine.complete(placed, count: item.tokens.count) else {
            Haptics.tap()
            return
        }
        var next = cursor
        next.scores["p1", default: 0] += 1
        if item.tokens.contains(where: { $0.owner == "p2" }) {
            next.scores["p2", default: 0] += 1
        }
        Haptics.success()
        move(RoundEngine.advance(next, plan: plan), nil)
    }

    func failBuild() {
        guard case .build = beat else { return }
        Haptics.warning()
        move(RoundEngine.advance(cursor, plan: plan), nil)
    }

    func applyRemote(itemID: String, player: String, choice: String) {
        guard mode == .twoPhones, case .listen(let item) = beat, item.id == itemID, player != localID else { return }
        choosePicture(choice)
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
        case .build: return "build"
        case nil: return "results"
        }
    }

    func understood() { move(RoundEngine.confirmDialog(cursor, plan: plan), nil) }

    private func move(_ next: RoundCursor, _ grade: GradedWord?) {
        cursor = RoundEngine.prepare(next, plan: plan)
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
        case .build: key = "dialog"
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
    @State private var pending: SpeechGrade?
    @State private var picked: String?
    @StateObject private var round = RoundController()

    var body: some View {
        ScreenBackground {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CloseBar {
                        if round.done {
                            closed = true
                            dismiss()
                        } else {
                            confirmLeave = true
                        }
                    }
                    .frame(width: 132)
                    ProgressView(value: round.lessonProgress)
                        .tint(Theme.sage)
                        .accessibilityLabel("Lektion \(Int(round.lessonProgress * 100)) Prozent")
                }
                TurnBanner(name: round.bannerTitle, left: round.turnIsLeft, text: round.bannerDetail)
                if round.done {
                    ResultsPane(
                        title: round.plan.unitTitle,
                        leftName: round.leftName,
                        rightName: round.rightName,
                        leftPoints: round.points(left: true),
                        rightPoints: round.points(left: false),
                        solo: round.mode == .solo,
                        again: {
                            closed = true
                            dismiss()
                        }
                    )
                } else {
                    ScrollView { beatBody.padding(.bottom, 8) }
                    lessonDock
                }
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
        .onChange(of: round.beat?.id) { _, _ in
            pending = nil
            picked = nil
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
            IntroPane(
                word: word,
                romanOpacity: romanOpacity(wordID: word.id),
                partnerURL: model.partnerVoiceURL(wordID: word.id),
                speak: { speech.speak(word.thai, clipID: word.id) },
                partner: { url in speech.speak(word.thai, file: url) },
                slow: { speech.speak(word.thai, slow: true, clipID: word.id) },
                next: round.nextIntro
            )
        case .listen(let item):
            ListenDuet(
                item: item,
                phase: round.cursor.listenPhase,
                romanOpacity: romanOpacity(wordID: item.answer.id),
                speech: speech,
                listener: round.display(item.listenerID),
                pending: $pending,
                picked: picked,
                onPick: { picked = $0 }
            )
            .id(item.id + round.cursor.listenPhase.rawValue)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
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
                wordID: turn.word.id,
                ownerID: turn.speakerID,
                pending: $pending
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
                pending: $pending
            )
            .id(turn.id)
        case .build(let item):
            BuildBoard(
                item: item,
                placed: round.cursor.buildPlaced,
                leftName: round.leftName,
                rightName: round.rightName,
                onTap: round.tapBuild,
                onFail: round.failBuild
            )
            .id(item.id)
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
            coach: !lessonSeen,
            extras: model.ownWords
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

    @ViewBuilder private var lessonDock: some View {
        if let pending {
            FeedbackBanner(grade: pending) { commit(pending) }
        } else if case .listen = round.beat, round.cursor.listenPhase == .point {
            FillButton(title: "CHECK", enabled: picked != nil) {
                guard let picked else { return }
                round.choosePicture(picked)
                self.picked = nil
            }
        } else if case .listen = round.beat, round.cursor.listenPhase == .result {
            let ok = round.cursor.speechUnderstood && round.cursor.pictureRight
            FeedbackBanner(grade: ok ? .sure : .miss) { round.finishListen() }
        } else if case .intro = round.beat {
            FillButton(title: "WEITER") { round.nextIntro() }
        } else if case .listen = round.beat, round.cursor.listenPhase == .explain || round.cursor.listenPhase == .pending {
            FillButton(title: "WEITER") { round.acceptExplain() }
        } else if case .listen = round.beat, round.cursor.listenPhase == .handoff {
            FillButton(title: "WEITER") { round.confirmHandoff() }
        } else if case .say = round.beat {
            FillButton(title: "CHECK", enabled: false) {}
        } else if case .dialog = round.beat {
            FillButton(title: "CHECK", enabled: false) {}
        }
    }

    private func commit(_ grade: SpeechGrade) {
        switch round.beat {
        case .listen:
            round.noteListenSpeech(grade)
        case .say(let turn):
            if grade != .miss { Haptics.success() } else { Haptics.warning() }
            round.finishSpeech(grade, wordID: turn.word.id, speakerID: turn.speakerID)
        case .dialog(let turn):
            if grade != .miss { Haptics.success() } else { Haptics.warning() }
            round.finishSpeech(grade, wordID: nil, speakerID: turn.speakerID)
        default:
            break
        }
        pending = nil
    }

    private func romanOpacity(wordID: String) -> Double {
        let stat = model.pathStats[wordID]
        return RomanFade.opacity(
            stage: model.pathSnapshot.stage,
            mastered: stat?.mastered == true,
            reviews: stat?.reviews ?? 0,
            pronunciation: stat?.pronunciation ?? 0,
            hidden: model.hideRoman
        )
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct IntroPane: View {
    let word: PathWord
    var romanOpacity: Double = 1
    var partnerURL: URL? = nil
    let speak: () -> Void
    var partner: (URL) -> Void = { _ in }
    let slow: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(word.emoji).font(.system(size: 88))
            if romanOpacity > 0.05 {
                ToneLine(roman: word.roman).opacity(romanOpacity)
            }
            Text(word.german).font(.title2)
            FillButton(title: "Anhören", systemImage: "speaker.wave.2", action: speak)
            if let partnerURL {
                FillButton(title: "Partnerstimme", systemImage: "person.wave.2") { partner(partnerURL) }
            }
            FillButton(title: "Langsam", systemImage: "tortoise", action: slow)
        }
    }
}

private struct ListenDuet: View {
    let item: ListenChallenge
    let phase: ListenPhase
    let romanOpacity: Double
    let speech: SpeechCoach
    let listener: String
    @Binding var pending: SpeechGrade?
    var picked: String?
    let onPick: (String) -> Void
    @State private var fallback = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            switch phase {
            case .explain, .pending:
                Text("Eine Person sagt das Wort, die andere hört nur zu und tippt das Bild, und den Punkt gibt es nur für beide zusammen.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            case .speak:
                Text(item.answer.emoji).font(.system(size: 72)).accessibilityHidden(true)
                Text(item.answer.german).font(.title2)
                SpeechListenDeck(
                    thai: item.answer.thai,
                    roman: item.answer.roman,
                    alternates: [],
                    romanOpacity: romanOpacity,
                    speech: speech,
                    grade: $pending,
                    fallback: $fallback
                )
                FillButton(title: "Anhören", systemImage: "speaker.wave.2") { speech.speak(item.answer.thai, clipID: item.answer.id) }
                FillButton(title: "Langsam", systemImage: "tortoise") { speech.speak(item.answer.thai, slow: true, clipID: item.answer.id) }
            case .handoff:
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(item.speakerID == item.listenerID
                     ? "Drehe das Handy um, dann tippe nur das Bild."
                     : "\(listener) nimmt das Handy. Das Wort bleibt verdeckt.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            case .point:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(item.choices.enumerated()), id: \.element.id) { index, choice in
                        Button {
                            Haptics.tap()
                            onPick(choice.id)
                        } label: {
                            Text(choice.emoji)
                                .font(.system(size: 56))
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(picked == choice.id ? Theme.accent : Color.clear, lineWidth: 4)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bild \(index + 1)")
                    }
                }
            case .result:
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: phase)
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
    var wordID: String? = nil
    var ownerID: String = "p1"
    @Binding var pending: SpeechGrade?
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
                grade: $pending,
                fallback: $fallback,
                hidesThaiUntilListening: hideThaiUntilGraded
            )
            FillButton(title: "Nochmal anhören", systemImage: "tortoise") { speech.speak(thai, slow: true) }
            if pending == .sure, let wordID {
                VoiceSaveButton(wordID: wordID, ownerID: ownerID, thai: thai)
            }
        }
    }
}

struct FeedbackBanner: View {
    let grade: SpeechGrade
    let weiter: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(grade == .miss ? "Noch nicht" : "Richtig")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(grade == .miss ? Theme.brick : Theme.sage)
            FillButton(title: "WEITER", color: grade == .miss ? Theme.brick : Theme.sage, action: weiter)
        }
        .padding(12)
        .background((grade == .miss ? Theme.brick : Theme.sage).opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct ResultsPane: View {
    let title: String
    let leftName: String
    let rightName: String
    let leftPoints: Int
    let rightPoints: Int
    let solo: Bool
    let again: () -> Void

    var body: some View {
        ZStack {
            Confetti()
            VStack(spacing: 12) {
                Text("🐘").font(.system(size: 72))
                Text("Ihr habt \(title) geschafft")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("\(leftPoints + rightPoints) XP")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.accent)
                Text(solo ? leftName : "\(leftName) und \(rightName)")
                    .foregroundStyle(.secondary)
                FillButton(title: "Zurück zum Pfad", action: again)
            }
        }
    }
}

private struct Confetti: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for index in 0..<28 {
                    let x = CGFloat((index * 53) % max(Int(size.width), 1))
                    let travel = (time * 36 + Double(index * 28)).truncatingRemainder(dividingBy: Double(size.height + 20))
                    let rect = CGRect(x: x, y: travel, width: 8, height: 8)
                    let color = index % 2 == 0 ? Theme.accent : Theme.sage
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BuildBoard: View {
    let item: BuildChallenge
    let placed: [Int]
    let leftName: String
    let rightName: String
    let onTap: (Int) -> Void
    let onFail: () -> Void
    @State private var started = Date()
    @State private var failed = false

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 0.2)) { context in
                let left = max(0, item.seconds - Int(context.date.timeIntervalSince(started)))
                Text("\(left) s")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(left < 6 ? Theme.brick : Theme.ink)
                    .onChange(of: left) { _, value in
                        if value == 0, !failed, placed.count < item.tokens.count {
                            failed = true
                            onFail()
                        }
                    }
            }
            Text(placed.map { item.tokens[$0].text }.joined(separator: " "))
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("Bisher \(placed.count) von \(item.tokens.count)")
            Text(item.german).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                column(owner: "p1", title: leftName, color: Theme.navy)
                column(owner: "p2", title: rightName, color: Theme.accent)
            }
        }
        .onAppear { started = Date() }
    }

    private func column(owner: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(color)
            ForEach(item.tokens.filter { $0.owner == owner }) { token in
                let used = placed.contains(token.id)
                Button {
                    guard !used else { return }
                    onTap(token.id)
                } label: {
                    Text(token.text)
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(color.opacity(used ? 0.08 : 0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(used)
                .accessibilityLabel("\(title), Teil \(token.id + 1)")
            }
        }
    }
}

private struct VoiceSaveButton: View {
    let wordID: String
    let ownerID: String
    let thai: String
    @EnvironmentObject private var model: AppModel
    @State private var recorder: AVAudioRecorder?
    @State private var recording = false
    @State private var saved = false

    var body: some View {
        Button {
            if saved { return }
            if recording {
                finish()
            } else {
                begin()
            }
        } label: {
            Text(saved ? "Stimme gemerkt" : (recording ? "Stopp" : "Stimme merken"))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Speichert eure Aussprache für spätere Runden.")
    }

    private func begin() {
        let url = model.voiceFile(wordID: wordID, ownerID: ownerID)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 24_000,
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        recording = recorder?.isRecording ?? false
    }

    private func finish() {
        recorder?.stop()
        recording = false
        let url = model.voiceFile(wordID: wordID, ownerID: ownerID)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        model.saveVoice(wordID: wordID, ownerID: ownerID, data: data)
        saved = true
        Haptics.success()
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
