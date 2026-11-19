import Foundation

struct WordRef: Equatable {
    let id: String
    let emoji: String
}

struct LineRef: Equatable {
    let thai: String
    let roman: String
    let german: String
}

struct DialogRef: Equatable {
    let id: String
    let a: LineRef
    let b: LineRef
}

struct UnitRef: Equatable {
    let id: String
    let stage: Int
    let title: String
    let words: [WordRef]
    let dialogs: [DialogRef]
}

public struct PathWord: Equatable, Identifiable, Hashable {
    public let id: String
    public let emoji: String
    public let thai: String
    public let roman: String
    public let german: String

    public init(id: String, emoji: String, thai: String, roman: String, german: String) {
        self.id = id
        self.emoji = emoji
        self.thai = thai
        self.roman = roman
        self.german = german
    }
}

public struct SpokenBit: Equatable {
    public let thai: String
    public let roman: String
    public let german: String

    public init(thai: String, roman: String, german: String) {
        self.thai = thai
        self.roman = roman
        self.german = german
    }
}

public struct DialogPair: Equatable, Identifiable {
    public let id: String
    public let a: SpokenBit
    public let b: SpokenBit

    public init(id: String, a: SpokenBit, b: SpokenBit) {
        self.id = id
        self.a = a
        self.b = b
    }
}

public struct LearnUnit: Equatable, Identifiable {
    public let id: String
    public let stage: Int
    public let title: String
    public let words: [PathWord]
    public let dialogs: [DialogPair]

    public init(id: String, stage: Int, title: String, words: [PathWord], dialogs: [DialogPair]) {
        self.id = id
        self.stage = stage
        self.title = title
        self.words = words
        self.dialogs = dialogs
    }
}

public struct WordStat: Codable, Equatable, Identifiable {
    public var id: String
    public var reviews: Int
    public var correct: Int
    public var streak: Int
    public var speechSum: Double
    public var speechCount: Int

    public init(id: String, reviews: Int = 0, correct: Int = 0, streak: Int = 0, speechSum: Double = 0, speechCount: Int = 0) {
        self.id = id
        self.reviews = reviews
        self.correct = correct
        self.streak = streak
        self.speechSum = speechSum
        self.speechCount = speechCount
    }

    public var pronunciation: Double {
        guard speechCount > 0 else { return 0 }
        return speechSum / Double(speechCount)
    }

    private enum CodingKeys: String, CodingKey {
        case id, reviews, correct, streak, speechSum, speechCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        reviews = try container.decodeIfPresent(Int.self, forKey: .reviews) ?? 0
        correct = try container.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        speechSum = try container.decodeIfPresent(Double.self, forKey: .speechSum) ?? 0
        speechCount = try container.decodeIfPresent(Int.self, forKey: .speechCount) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reviews, forKey: .reviews)
        try container.encode(correct, forKey: .correct)
        try container.encode(streak, forKey: .streak)
        try container.encode(speechSum, forKey: .speechSum)
        try container.encode(speechCount, forKey: .speechCount)
    }

    public var mastered: Bool {
        guard reviews >= 2, streak >= 2 else { return false }
        return Double(correct) / Double(reviews) >= 0.8
    }

    public func record(correct answer: Bool) -> WordStat {
        var copy = self
        copy.reviews += 1
        if answer {
            copy.correct += 1
            copy.streak += 1
        } else {
            copy.streak = 0
        }
        return copy
    }

    public func recordSpeech(_ grade: SpeechGrade) -> WordStat {
        var copy = record(correct: grade != .miss)
        copy.speechSum += grade.value
        copy.speechCount += 1
        return copy
    }
}

public struct PathSnapshot: Equatable {
    public let stage: Int
    public let unitIndex: Int
    public let unitCount: Int
    public let unitTitle: String
    public let label: String

    public init(stage: Int, unitIndex: Int, unitCount: Int, unitTitle: String, label: String) {
        self.stage = stage
        self.unitIndex = unitIndex
        self.unitCount = unitCount
        self.unitTitle = unitTitle
        self.label = label
    }
}

public enum LearningPath {
    public static let unlockRatio = 0.8

    public static func load(from catalog: ThaiCatalog) -> [LearnUnit] {
        let byID = Dictionary(catalog.phrases.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return PathData.refs.map { ref in
            let words = ref.words.compactMap { word -> PathWord? in
                guard let phrase = byID[word.id] else { return nil }
                return PathWord(id: phrase.id, emoji: word.emoji, thai: phrase.thai, roman: phrase.roman, german: phrase.german)
            }
            let dialogs = ref.dialogs.map { dialog in
                DialogPair(
                    id: dialog.id,
                    a: SpokenBit(thai: dialog.a.thai, roman: dialog.a.roman, german: dialog.a.german),
                    b: SpokenBit(thai: dialog.b.thai, roman: dialog.b.roman, german: dialog.b.german)
                )
            }
            return LearnUnit(id: ref.id, stage: ref.stage, title: ref.title, words: words, dialogs: dialogs)
        }
    }

    public static func ratio(_ unit: LearnUnit, stats: [String: WordStat]) -> Double {
        guard !unit.words.isEmpty else { return 1 }
        let mastered = unit.words.filter { stats[$0.id]?.mastered == true }.count
        return Double(mastered) / Double(unit.words.count)
    }

    public static func isUnlocked(_ index: Int, units: [LearnUnit], stats: [String: WordStat]) -> Bool {
        guard units.indices.contains(index) else { return false }
        if index == 0 { return true }
        return ratio(units[index - 1], stats: stats) >= unlockRatio
    }

    public static func currentIndex(units: [LearnUnit], stats: [String: WordStat]) -> Int {
        guard !units.isEmpty else { return 0 }
        for index in units.indices where isUnlocked(index, units: units, stats: stats) {
            if ratio(units[index], stats: stats) < unlockRatio { return index }
        }
        return units.count - 1
    }

    public static func snapshot(units: [LearnUnit], stats: [String: WordStat]) -> PathSnapshot {
        let index = currentIndex(units: units, stats: stats)
        let unit = units.indices.contains(index) ? units[index] : nil
        let stage = unit?.stage ?? 1
        let inStage = units.enumerated().filter { $0.element.stage == stage }
        let position = inStage.firstIndex { $0.offset == index }.map { $0 + 1 } ?? 1
        let title = unit?.title ?? ""
        let label = "Stufe \(stage) · Einheit \(position) von \(inStage.count)"
        return PathSnapshot(stage: stage, unitIndex: position, unitCount: inStage.count, unitTitle: title, label: label)
    }

    public static func chapterTitle(stage: Int) -> String {
        switch stage {
        case 1: return "Kapitel 1: Erste Worte"
        case 2: return "Kapitel 2: Im Restaurant"
        default: return "Kapitel \(stage)"
        }
    }
}

public enum MapNodeState: String, Equatable {
    case locked, current, done
}

public struct MapNode: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let chapter: String?
    public let state: MapNodeState
    public let chest: Bool
    public let stage: Int

    public init(id: String, title: String, emoji: String, chapter: String?, state: MapNodeState, chest: Bool, stage: Int) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.chapter = chapter
        self.state = state
        self.chest = chest
        self.stage = stage
    }
}

public enum PathMap {
    public static func nodes(units: [LearnUnit], stats: [String: WordStat], checkedStages: Set<Int>) -> [MapNode] {
        let current = LearningPath.currentIndex(units: units, stats: stats)
        var nodes: [MapNode] = []
        var lastStage = 0
        for (index, unit) in units.enumerated() {
            let chapter = unit.stage != lastStage ? LearningPath.chapterTitle(stage: unit.stage) : nil
            lastStage = unit.stage
            let state = lessonState(index: index, unit: unit, current: current, units: units, stats: stats)
            nodes.append(MapNode(
                id: unit.id,
                title: unit.title,
                emoji: unit.words.first?.emoji ?? "🐘",
                chapter: chapter,
                state: state,
                chest: false,
                stage: unit.stage
            ))
            let endOfStage = index + 1 == units.count || units[index + 1].stage != unit.stage
            if endOfStage {
                let done = units.enumerated().filter { $0.element.stage == unit.stage }.allSatisfy {
                    LearningPath.ratio($0.element, stats: stats) >= LearningPath.unlockRatio
                }
                let chestState: MapNodeState
                if checkedStages.contains(unit.stage) { chestState = .done }
                else if done { chestState = .current }
                else { chestState = .locked }
                nodes.append(MapNode(
                    id: "chest-\(unit.stage)",
                    title: unit.stage >= 2 ? "Restaurant-Test" : "Alltags-Check",
                    emoji: "🎁",
                    chapter: nil,
                    state: chestState,
                    chest: true,
                    stage: unit.stage
                ))
            }
        }
        return nodes
    }

    private static func lessonState(index: Int, unit: LearnUnit, current: Int, units: [LearnUnit], stats: [String: WordStat]) -> MapNodeState {
        if LearningPath.ratio(unit, stats: stats) >= LearningPath.unlockRatio { return .done }
        if !LearningPath.isUnlocked(index, units: units, stats: stats) { return .locked }
        return index == current ? .current : .locked
    }
}
