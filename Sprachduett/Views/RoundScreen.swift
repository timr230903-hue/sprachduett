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

struct RoundScreen: View {
    let together: Bool
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @StateObject private var round = RoundController()

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
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
        .onAppear(perform: boot)
        .onChange(of: model.duo.liveClaim?.at) { _, _ in
            guard let claim = model.duo.liveClaim else { return }
            round.applyRemote(itemID: claim.itemID, player: claim.playerID, choice: claim.choiceID)
        }
    }

    @ViewBuilder private var beatBody: some View {
        switch round.beat {
        case .intro(let word):
            IntroPane(word: word, speak: { speech.speak(word.thai) }, next: round.nextIntro)
        case .listen(let item):
            ListenBoard(item: item, mode: round.mode, left: round.leftName, right: round.rightName) { player, choice in
                round.tap(player: player, choice: choice)
            }
        case .say(let turn):
            SayPane(
                turn: turn,
                revealed: round.cursor.phase == .check,
                speak: { speech.speak(turn.word.thai) },
                said: round.saidIt,
                judge: round.judged
            )
        case .dialog(let turn):
            DialogPane(turn: turn, speak: { speech.speak(turn.line.thai) }, understood: round.understood)
        case nil:
            EmptyView()
        }
    }

    private func boot() {
        round.onFinish = { stats in
            lessonSeen = true
            let playedTogether = together && round.mode != .solo
            model.rememberRound(Dictionary(stats.map { ($0.id, $0) }, uniquingKeysWith: { _, next in next }), together: playedTogether)
        }
        round.onClaim = { item, player, choice in
            model.publishClaim(itemID: item, playerID: player, choiceID: choice)
        }
        round.start(
            units: model.pathUnits,
            stats: model.pathStats,
            together: together,
            partnerConnected: model.partnerConnected,
            left: model.me.name.isEmpty ? "Du" : model.me.name,
            right: model.partner?.name ?? "Partner",
            localID: model.me.id,
            partnerID: model.partner?.id ?? "p2",
            coach: !lessonSeen
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
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(left ? Theme.coral : Theme.mango)
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
    let next: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(word.emoji).font(.system(size: 88))
            ToneLine(roman: word.roman)
            Text(word.german).font(.title2)
            FillButton(title: "Anhören", systemImage: "speaker.wave.2", action: speak)
            FillButton(title: "Weiter", color: Theme.leaf, action: next)
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
                choiceColumn(title: left, player: "p1", color: Theme.coral)
                choiceColumn(title: right, player: "p2", color: Theme.mango)
            }
        } else {
            choiceColumn(title: "", player: "p1", color: Theme.coral)
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

private struct SayPane: View {
    let turn: SayTurn
    let revealed: Bool
    let speak: () -> Void
    let said: () -> Void
    let judge: (Bool) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(turn.word.emoji).font(.system(size: 88))
            if revealed {
                Text(turn.word.thai).font(.system(size: 40, weight: .bold, design: .rounded))
                ToneLine(roman: turn.word.roman)
                Text(turn.word.german).foregroundStyle(.secondary)
                FillButton(title: "Anhören", systemImage: "speaker.wave.2", action: speak)
                FillButton(title: "Richtig", color: Theme.leaf) { judge(true) }
                SoftButton(title: "Nochmal") { judge(false) }
            } else {
                Text(turn.word.german).font(.title)
                FillButton(title: "Gesagt", color: Theme.leaf, action: said)
            }
        }
    }
}

private struct DialogPane: View {
    let turn: DialogTurn
    let speak: () -> Void
    let understood: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(turn.line.thai).font(.system(size: 36, weight: .bold, design: .rounded))
            ToneLine(roman: turn.line.roman)
            Text(turn.line.german).font(.title3).foregroundStyle(.secondary)
            FillButton(title: "Anhören", systemImage: "speaker.wave.2", action: speak)
            FillButton(title: "Verstanden", color: Theme.leaf, action: understood)
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
                .foregroundStyle(Theme.coral)
            if !solo {
                Text("\(rightName): \(rightPoints)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.mango)
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
        case .falling: return Theme.coral
        case .high: return Theme.mango
        case .rising: return Theme.leaf
        }
    }
}
