import Foundation

public enum PlayMode: Equatable {
    case solo
    case togetherOnePhone
    case twoPhones

    public static func resolve(together: Bool, partnerConnected: Bool) -> PlayMode {
        if !together { return .solo }
        return partnerConnected ? .twoPhones : .togetherOnePhone
    }
}

public struct ListenChallenge: Equatable, Identifiable {
    public let id: String
    public let answer: PathWord
    public let choices: [PathWord]

    public init(id: String, answer: PathWord, choices: [PathWord]) {
        self.id = id
        self.answer = answer
        self.choices = choices
    }
}

public struct SayTurn: Equatable, Identifiable {
    public let id: String
    public let word: PathWord
    public let speakerID: String

    public init(id: String, word: PathWord, speakerID: String) {
        self.id = id
        self.word = word
        self.speakerID = speakerID
    }
}

public struct DialogTurn: Equatable, Identifiable {
    public let id: String
    public let line: SpokenBit
    public let speakerID: String

    public init(id: String, line: SpokenBit, speakerID: String) {
        self.id = id
        self.line = line
        self.speakerID = speakerID
    }
}

public enum Beat: Equatable, Identifiable {
    case intro(PathWord)
    case listen(ListenChallenge)
    case say(SayTurn)
    case dialog(DialogTurn)

    public var id: String {
        switch self {
        case .intro(let word): return "intro-\(word.id)"
        case .listen(let item): return "listen-\(item.id)"
        case .say(let turn): return "say-\(turn.id)"
        case .dialog(let turn): return "dialog-\(turn.id)"
        }
    }

    public var wordID: String? {
        switch self {
        case .intro(let word): return word.id
        case .listen(let item): return item.answer.id
        case .say(let turn): return turn.word.id
        case .dialog: return nil
        }
    }
}

public struct RoundPlan: Equatable {
    public let beats: [Beat]
    public let label: String
    public let unitTitle: String

    public init(beats: [Beat], label: String, unitTitle: String) {
        self.beats = beats
        self.label = label
        self.unitTitle = unitTitle
    }
}

public enum SayPhase: String, Equatable {
    case speak
    case check
}

public struct RoundCursor: Equatable {
    public var index: Int
    public var phase: SayPhase
    public var scores: [String: Int]
    public var missed: Set<String>

    public init(index: Int = 0, phase: SayPhase = .speak, scores: [String: Int] = [:], missed: Set<String> = []) {
        self.index = index
        self.phase = phase
        self.scores = scores
        self.missed = missed
    }

    public var finished: Bool { index < 0 }
}

public struct GradedWord: Equatable {
    public let wordID: String
    public let correct: Bool
    public let playerID: String?

    public init(wordID: String, correct: Bool, playerID: String?) {
        self.wordID = wordID
        self.correct = correct
        self.playerID = playerID
    }
}

public enum RoundBuilder {
    public static func build(units: [LearnUnit], stats: [String: WordStat], seed: UInt64, together: Bool) -> RoundPlan {
        let snapshot = LearningPath.snapshot(units: units, stats: stats)
        let index = LearningPath.currentIndex(units: units, stats: stats)
        guard units.indices.contains(index) else {
            return RoundPlan(beats: [], label: snapshot.label, unitTitle: snapshot.unitTitle)
        }
        let unit = units[index]
        let fresh = unit.words.filter { (stats[$0.id]?.reviews ?? 0) == 0 }
        let reviewPool = units.enumerated()
            .filter { LearningPath.isUnlocked($0.offset, units: units, stats: stats) }
            .flatMap(\.element.words)
            .filter { word in
                let stat = stats[word.id]
                return (stat?.reviews ?? 0) > 0 && stat?.mastered != true
            }
        var rng = SeededRNG(seed: seed == 0 ? 1 : seed)
        let newWords = Array(fresh.prefix(4))
        var quiz = newWords
        if quiz.count < 4 {
            let extra = rng.shuffled(reviewPool.filter { word in !quiz.contains { $0.id == word.id } })
            quiz.append(contentsOf: extra.prefix(4 - quiz.count))
        }
        if quiz.isEmpty {
            quiz = Array(unit.words.prefix(4))
        }
        let unlockedWords = units.enumerated()
            .filter { LearningPath.isUnlocked($0.offset, units: units, stats: stats) }
            .flatMap(\.element.words)
        var beats: [Beat] = newWords.map { .intro($0) }
        for (offset, word) in quiz.enumerated() {
            let choices = choices(for: word, pool: quiz, extra: unlockedWords, rng: &rng)
            beats.append(.listen(ListenChallenge(id: "\(word.id)-\(offset)", answer: word, choices: choices)))
        }
        let first = "p1"
        let second = together ? "p2" : "p1"
        for (offset, word) in quiz.enumerated() {
            let speaker = offset % 2 == 0 ? first : second
            beats.append(.say(SayTurn(id: "\(word.id)-say-\(offset)", word: word, speakerID: speaker)))
        }
        let pairs = unit.dialogs.isEmpty ? [] : pickDialogs(unit.dialogs, count: 2, rng: &rng)
        for pair in pairs {
            beats.append(.dialog(DialogTurn(id: "\(pair.id)-a", line: pair.a, speakerID: first)))
            beats.append(.dialog(DialogTurn(id: "\(pair.id)-b", line: pair.b, speakerID: second)))
        }
        return RoundPlan(beats: beats, label: snapshot.label, unitTitle: unit.title)
    }

    private static func choices(for answer: PathWord, pool: [PathWord], extra: [PathWord], rng: inout SeededRNG) -> [PathWord] {
        var set = pool.filter { $0.id != answer.id }
        if set.count < 3 {
            let more = extra.filter { item in item.id != answer.id && !set.contains { $0.id == item.id } }
            set.append(contentsOf: rng.shuffled(more).prefix(3 - set.count))
        }
        var picked = Array(rng.shuffled(set).prefix(3))
        picked.append(answer)
        return rng.shuffled(picked)
    }

    private static func pickDialogs(_ dialogs: [DialogPair], count: Int, rng: inout SeededRNG) -> [DialogPair] {
        Array(rng.shuffled(dialogs).prefix(count))
    }
}

public enum RoundEngine {
    public static func beat(_ plan: RoundPlan, _ cursor: RoundCursor) -> Beat? {
        guard plan.beats.indices.contains(cursor.index) else { return nil }
        return plan.beats[cursor.index]
    }

    public static func advance(_ cursor: RoundCursor, plan: RoundPlan) -> RoundCursor {
        var next = cursor
        next.index += 1
        next.phase = .speak
        next.missed = []
        if next.index >= plan.beats.count { next.index = -1 }
        return next
    }

    public static func listenTap(
        _ cursor: RoundCursor,
        plan: RoundPlan,
        playerID: String,
        choiceID: String,
        seats: [String]
    ) -> (RoundCursor, GradedWord?) {
        guard case .listen(let item)? = beat(plan, cursor) else { return (cursor, nil) }
        if cursor.missed.contains(playerID) { return (cursor, nil) }
        var next = cursor
        if choiceID == item.answer.id {
            next.scores[playerID, default: 0] += 1
            next = advance(next, plan: plan)
            return (next, GradedWord(wordID: item.answer.id, correct: true, playerID: playerID))
        }
        next.missed.insert(playerID)
        let waiting = seats.filter { !next.missed.contains($0) }
        if waiting.isEmpty {
            next = advance(next, plan: plan)
            return (next, GradedWord(wordID: item.answer.id, correct: false, playerID: nil))
        }
        return (next, nil)
    }

    public static func revealSay(_ cursor: RoundCursor, plan: RoundPlan) -> RoundCursor {
        guard case .say = beat(plan, cursor), cursor.phase == .speak else { return cursor }
        var next = cursor
        next.phase = .check
        return next
    }

    public static func judgeSay(_ cursor: RoundCursor, plan: RoundPlan, correct: Bool) -> (RoundCursor, GradedWord?) {
        guard case .say(let turn) = beat(plan, cursor), cursor.phase == .check else { return (cursor, nil) }
        var next = cursor
        if correct {
            next.scores[turn.speakerID, default: 0] += 1
        }
        next = advance(next, plan: plan)
        return (next, GradedWord(wordID: turn.word.id, correct: correct, playerID: correct ? turn.speakerID : nil))
    }

    public static func confirmDialog(_ cursor: RoundCursor, plan: RoundPlan) -> RoundCursor {
        guard case .dialog(let turn) = beat(plan, cursor) else { return cursor }
        var next = cursor
        next.scores[turn.speakerID, default: 0] += 1
        return advance(next, plan: plan)
    }

    public static func apply(_ stats: [String: WordStat], _ grade: GradedWord) -> [String: WordStat] {
        var copy = stats
        let current = copy[grade.wordID] ?? WordStat(id: grade.wordID)
        copy[grade.wordID] = current.record(correct: grade.correct)
        return copy
    }

    public static func applySpeech(_ stats: [String: WordStat], wordID: String, grade: SpeechGrade) -> [String: WordStat] {
        var copy = stats
        let current = copy[wordID] ?? WordStat(id: wordID)
        copy[wordID] = current.recordSpeech(grade)
        return copy
    }

    /// Neue Wörter stehen als Intro, bevor sie abgefragt werden.
    public static func introsComeFirst(_ plan: RoundPlan) -> Bool {
        var introduced = Set<String>()
        for beat in plan.beats {
            switch beat {
            case .intro(let word):
                introduced.insert(word.id)
            case .listen(let item):
                if (plan.beats.contains { if case .intro(let word) = $0 { return word.id == item.answer.id } else { return false } })
                    && !introduced.contains(item.answer.id) { return false }
            case .say(let turn):
                if (plan.beats.contains { if case .intro(let word) = $0 { return word.id == turn.word.id } else { return false } })
                    && !introduced.contains(turn.word.id) { return false }
            case .dialog:
                break
            }
        }
        return true
    }
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

extension SeededRNG {
    mutating func shuffled<T>(_ values: [T]) -> [T] {
        var copy = values
        guard copy.count > 1 else { return copy }
        for index in stride(from: copy.count - 1, through: 1, by: -1) {
            let swap = Int(next() % UInt64(index + 1))
            copy.swapAt(index, swap)
        }
        return copy
    }
}
