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

    public init(id: String, reviews: Int = 0, correct: Int = 0, streak: Int = 0) {
        self.id = id
        self.reviews = reviews
        self.correct = correct
        self.streak = streak
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
}
