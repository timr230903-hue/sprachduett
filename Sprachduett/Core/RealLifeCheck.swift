import Foundation

public struct CheckPrompt: Equatable, Identifiable {
    public let id: String
    public let canDo: String
    public let waiterThai: String
    public let instruction: String
    public let expected: String
    public let alternates: [String]

    public init(id: String, canDo: String, waiterThai: String, instruction: String, expected: String, alternates: [String] = []) {
        self.id = id
        self.canDo = canDo
        self.waiterThai = waiterThai
        self.instruction = instruction
        self.expected = expected
        self.alternates = alternates
    }
}

public struct CheckQuestion: Equatable, Identifiable {
    public let id: String
    public let canDo: String
    public let audio: String
    public let choices: [String]
    public let answer: Int

    public init(id: String, canDo: String, audio: String, choices: [String], answer: Int) {
        self.id = id
        self.canDo = canDo
        self.audio = audio
        self.choices = choices
        self.answer = answer
    }
}

public enum CheckStep: Equatable, Identifiable {
    case speak(CheckPrompt)
    case listen(CheckQuestion)

    public var id: String {
        switch self {
        case .speak(let prompt): return prompt.id
        case .listen(let question): return question.id
        }
    }
}

public struct LifeCheckOutcome: Equatable {
    public let achieved: [String]
    public let missing: [String]
    public let speechAverage: Double
    public let comprehension: Double

    public var sentence: String {
        let yes = achieved.isEmpty ? "noch nichts Sicheres" : achieved.joined(separator: ", ")
        let no = missing.isEmpty ? "nichts Offenes" : missing.joined(separator: ", ")
        return "Ihr könntet jetzt in Bangkok: \(yes). Noch nicht: \(no)."
    }
}

public struct CheckRecord: Codable, Equatable, Identifiable {
    public var id: String
    public var date: Date
    public var level: Int
    public var sentence: String
    public var achieved: [String]

    public init(id: String, date: Date, level: Int, sentence: String, achieved: [String]) {
        self.id = id
        self.date = date
        self.level = level
        self.sentence = sentence
        self.achieved = achieved
    }
}

public struct UsageLog: Codable, Equatable {
    public var roundsStarted: Int
    public var roundsFinished: Int
    public var totalSeconds: Double
    public var abandonedByGame: [String: Int]

    public init(roundsStarted: Int = 0, roundsFinished: Int = 0, totalSeconds: Double = 0, abandonedByGame: [String: Int] = [:]) {
        self.roundsStarted = roundsStarted
        self.roundsFinished = roundsFinished
        self.totalSeconds = totalSeconds
        self.abandonedByGame = abandonedByGame
    }

    public var abandoned: Int { abandonedByGame.values.reduce(0, +) }

    public var averageSeconds: Double? {
        guard roundsFinished > 0 else { return nil }
        return totalSeconds / Double(roundsFinished)
    }

    public func started() -> UsageLog {
        var copy = self
        copy.roundsStarted += 1
        return copy
    }

    public func finished(seconds: Double) -> UsageLog {
        var copy = self
        copy.roundsFinished += 1
        copy.totalSeconds += max(0, seconds)
        return copy
    }

    public func abandoned(game: String) -> UsageLog {
        var copy = self
        copy.abandonedByGame[game, default: 0] += 1
        return copy
    }
}

public struct FeedbackNote: Codable, Equatable, Identifiable {
    public var id: String
    public var date: Date
    public var screen: String
    public var note: String

    public init(id: String, date: Date, screen: String, note: String) {
        self.id = id
        self.date = date
        self.screen = screen
        self.note = note
    }

    public var exportLine: String {
        "\(date) [\(screen)] \(note)"
    }
}

public enum RealLifeCheck {
    public static let month: TimeInterval = 30 * 24 * 60 * 60

    public static func steps(level: Int) -> [CheckStep] {
        level >= 2 ? restaurant : greeting
    }

    public static func isDue(stageMastered: Bool, last: Date?, now: Date) -> Bool {
        guard stageMastered else { return false }
        guard let last else { return true }
        return now.timeIntervalSince(last) >= month
    }

    public static func outcome(grades: [(canDo: String, grade: SpeechGrade)], comprehension: [(canDo: String, correct: Bool)]) -> LifeCheckOutcome {
        var speechByCanDo: [String: [SpeechGrade]] = [:]
        for item in grades { speechByCanDo[item.canDo, default: []].append(item.grade) }
        var heardByCanDo: [String: [Bool]] = [:]
        for item in comprehension { heardByCanDo[item.canDo, default: []].append(item.correct) }
        let names = Array(Set(speechByCanDo.keys).union(heardByCanDo.keys)).sorted()
        var achieved: [String] = []
        var missing: [String] = []
        for name in names {
            let speechOK = (speechByCanDo[name] ?? []).allSatisfy { $0 != .miss }
            let heardOK = (heardByCanDo[name] ?? []).allSatisfy { $0 }
            let hasSpeech = speechByCanDo[name] != nil
            if speechOK && heardOK && (hasSpeech || heardByCanDo[name] != nil) {
                achieved.append(name)
            } else {
                missing.append(name)
            }
        }
        let values = grades.map(\.grade.value)
        let speechAverage = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let heard = comprehension.map { $0.correct ? 1.0 : 0 }
        let comprehensionScore = heard.isEmpty ? 0 : heard.reduce(0, +) / Double(heard.count)
        return LifeCheckOutcome(achieved: achieved, missing: missing, speechAverage: speechAverage, comprehension: comprehensionScore)
    }

    private static let greeting: [CheckStep] = [
        .speak(CheckPrompt(
            id: "g-hello", canDo: "Hallo sagen",
            waiterThai: "สวัสดีค่ะ",
            instruction: "Begrüßt zurück.",
            expected: "สวัสดี",
            alternates: ["สวัสดีครับ", "สวัสดีค่ะ"]
        )),
        .speak(CheckPrompt(
            id: "g-thanks", canDo: "Danke sagen",
            waiterThai: "เชิญค่ะ",
            instruction: "Sagt Danke.",
            expected: "ขอบคุณ",
            alternates: ["ขอบคุณครับ", "ขอบคุณค่ะ"]
        )),
        .speak(CheckPrompt(
            id: "g-yes", canDo: "Ja sagen",
            waiterThai: "สบายดีไหม",
            instruction: "Antwortet mit Ja.",
            expected: "ใช่",
            alternates: ["สบายดี", "ใช่ครับ"]
        )),
        .listen(CheckQuestion(
            id: "g-hear", canDo: "eine Begrüßung verstehen",
            audio: "สวัสดี",
            choices: ["Hallo", "Danke", "Wasser"],
            answer: 0
        )),
        .speak(CheckPrompt(
            id: "g-ten", canDo: "bis zehn zählen",
            waiterThai: "เท่าไหร่",
            instruction: "Sagt die Zahl zehn.",
            expected: "สิบ",
            alternates: ["สิบบาท"]
        )),
    ]

    private static let restaurant: [CheckStep] = [
        .speak(CheckPrompt(
            id: "r-order", canDo: "etwas zu essen bestellen",
            waiterThai: "สั่งอะไรดีคะ",
            instruction: "Bestellt Pad Thai.",
            expected: "เอาผัดไทย",
            alternates: ["ผัดไทย", "เอาผัดไทยหนึ่งจาน"]
        )),
        .speak(CheckPrompt(
            id: "r-price", canDo: "nach dem Preis fragen",
            waiterThai: "ได้เลยค่ะ",
            instruction: "Fragt, was es kostet.",
            expected: "เท่าไหร่",
            alternates: ["ราคาเท่าไหร่", "อันนี้เท่าไหร่"]
        )),
        .listen(CheckQuestion(
            id: "r-hear-price", canDo: "einen Preis verstehen",
            audio: "สิบบาท",
            choices: ["Zehn Baht", "Hundert Baht", "Wasser"],
            answer: 0
        )),
        .speak(CheckPrompt(
            id: "r-thanks", canDo: "Danke sagen",
            waiterThai: "เชิญชิมค่ะ",
            instruction: "Sagt Danke.",
            expected: "ขอบคุณ",
            alternates: ["ขอบคุณมาก", "ขอบคุณค่ะ"]
        )),
        .speak(CheckPrompt(
            id: "r-bill", canDo: "nach der Rechnung fragen",
            waiterThai: "อย่างอื่นอีกไหมคะ",
            instruction: "Bittet um die Rechnung.",
            expected: "เช็คบิล",
            alternates: ["เก็บเงิน", "เช็คบิลด้วย"]
        )),
        .speak(CheckPrompt(
            id: "r-from", canDo: "sagen, woher ihr kommt",
            waiterThai: "มาจากไหนคะ",
            instruction: "Sagt, dass ihr aus Deutschland kommt.",
            expected: "มาจากเยอรมนี",
            alternates: ["เยอรมนี", "มาจากเยอรมัน"]
        )),
    ]
}
