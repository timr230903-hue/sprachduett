import Foundation

public enum SpeechGrade: String, Codable, Equatable {
    case sure
    case close
    case miss

    public var value: Double {
        switch self {
        case .sure: return 1
        case .close: return 0.6
        case .miss: return 0
        }
    }
}

public enum SpeechScore {
    /// Mai ek, tho, tri, chattawa. Ohne sie bleibt die Silbe, der Ton nicht.
    private static let toneMarks: Set<UInt32> = [0x0E48, 0x0E49, 0x0E4A, 0x0E4B]

    public static func withoutTones(_ text: String) -> String {
        let source = SpeechMatch.stripParticles(text)
        let kept = source.unicodeScalars.filter { !toneMarks.contains($0.value) }
        return String(String.UnicodeScalarView(kept))
    }

    /// Grün ab klarem Treffer, gelb bei fast gleichem Wort (oft nur der Ton), sonst rot.
    public static func grade(recognized: String, expected: String, alternates: [String] = []) -> SpeechGrade {
        let targets = [expected] + alternates.filter { !$0.isEmpty }
        if targets.contains(where: { SpeechMatch.accepts(recognized: recognized, expectedThai: $0) }) {
            return .sure
        }
        let heardBare = withoutTones(recognized)
        var bestBare = 0.0
        var bestFull = 0.0
        for target in targets {
            bestBare = max(bestBare, SpeechMatch.similarity(heardBare, withoutTones(target)))
            bestFull = max(bestFull, SpeechMatch.similarity(SpeechMatch.stripParticles(recognized), SpeechMatch.stripParticles(target)))
        }
        if bestBare >= 0.99 { return .close }
        if bestFull >= 0.75 { return .close }
        return .miss
    }

    /// Silben der Zielzeile, live eingefärbt. Leer und noch nicht fertig bleibt grau.
    public static func liveTokens(recognized: String, expected: String, roman: String, finished: Bool) -> [LiveToken] {
        let labels = syllableLabels(expected: expected, roman: roman)
        let count = max(labels.count, 1)
        let expectedCore = SpeechMatch.stripParticles(expected)
        let heardCore = SpeechMatch.stripParticles(recognized)
        if heardCore.isEmpty {
            let light: TokenLight = finished ? .miss : .pending
            return labels.enumerated().map { LiveToken(index: $0.offset, text: $0.element, light: light) }
        }
        if heardCore == expectedCore {
            return labels.enumerated().map { LiveToken(index: $0.offset, text: $0.element, light: .sure) }
        }
        let bareHeard = withoutTones(heardCore)
        let bareExpected = withoutTones(expectedCore)
        if !bareHeard.isEmpty, bareHeard == bareExpected {
            return labels.enumerated().map { LiveToken(index: $0.offset, text: $0.element, light: .close) }
        }
        let matched = commonPrefixCount(bareHeard, bareExpected)
        let total = max(Array(bareExpected).count, 1)
        let diverged = matched < Array(bareHeard).count
        return labels.enumerated().map { offset, text in
            let start = total * offset / count
            let end = max(total * (offset + 1) / count, start + 1)
            let light: TokenLight
            if matched >= end {
                light = .sure
            } else if matched > start {
                light = .close
            } else if diverged || finished {
                light = .miss
            } else {
                light = .pending
            }
            return LiveToken(index: offset, text: text, light: light)
        }
    }

    private static func syllableLabels(expected: String, roman: String) -> [String] {
        let pieces = roman.split { $0 == " " || $0 == "-" }.map(String.init).filter { !$0.isEmpty }
        if !pieces.isEmpty { return pieces }
        let words = expected.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
        return words.isEmpty ? [expected] : words
    }

    private static func commonPrefixCount(_ left: String, _ right: String) -> Int {
        let a = Array(left)
        let b = Array(right)
        var index = 0
        while index < a.count, index < b.count, a[index] == b[index] {
            index += 1
        }
        return index
    }
}

public enum TokenLight: String, Equatable {
    case pending
    case sure
    case close
    case miss
}

public struct LiveToken: Equatable, Identifiable {
    public let index: Int
    public let text: String
    public let light: TokenLight
    public var id: Int { index }

    public init(index: Int, text: String, light: TokenLight) {
        self.index = index
        self.text = text
        self.light = light
    }
}

public struct PronunciationNote: Equatable {
    public let message: String
    public let syllable: String?
    public let tone: ToneColor?

    public init(message: String, syllable: String? = nil, tone: ToneColor? = nil) {
        self.message = message
        self.syllable = syllable
        self.tone = tone
    }
}

public enum SpeechHint {
    /// Sagt, welcher Ton oder welche Vokallänge wahrscheinlich daneben lag.
    public static func explain(recognized: String, expected: String, roman: String) -> PronunciationNote {
        let grade = SpeechScore.grade(recognized: recognized, expected: expected)
        let syllables = RomanTones.syllables(roman)
        let marked = syllables.first { $0.tone != .mid } ?? syllables.first
        if grade == .sure {
            return PronunciationNote(message: "Das war die Zeile.")
        }
        let expectedCore = SpeechMatch.stripParticles(expected)
        let heardCore = SpeechMatch.stripParticles(recognized)
        if heardCore.isEmpty {
            return PronunciationNote(message: "Nichts gehört. Näher ans Mikrofon, dann langsam noch einmal.")
        }
        if !heardCore.isEmpty, SpeechScore.withoutTones(heardCore) == SpeechScore.withoutTones(expectedCore) {
            let name = toneName(marked?.tone ?? .mid)
            return PronunciationNote(
                message: "Der Ton sitzt noch nicht: \(name). Hört langsam und folgt dem Pfeil.",
                syllable: marked?.text,
                tone: marked?.tone
            )
        }
        if grade == .close, hasLongVowel(roman) {
            return PronunciationNote(
                message: "Der Vokal ist lang. Zieht ihn, dann langsam noch einmal.",
                syllable: marked?.text,
                tone: marked?.tone
            )
        }
        if grade == .close {
            return PronunciationNote(
                message: "Fast dasselbe Wort. Hört langsam die Silben einzeln.",
                syllable: marked?.text,
                tone: marked?.tone
            )
        }
        return PronunciationNote(message: "Das war ein anderes Wort. Langsam noch einmal, Silbe für Silbe.")
    }

    private static func toneName(_ tone: ToneColor) -> String {
        switch tone {
        case .mid: return "Mittelton"
        case .low: return "tiefer Ton"
        case .falling: return "fallender Ton"
        case .high: return "hoher Ton"
        case .rising: return "steigender Ton"
        }
    }

    private static func hasLongVowel(_ roman: String) -> Bool {
        let bare = roman.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
        return bare.range(of: "aa|ee|ii|oo|uu|ʉʉ|ɯɯ", options: .regularExpression) != nil
    }
}

public enum ListenMeter {
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    /// 0 ist Stille, gesprochene Silben liegen deutlich darüber.
    public static func unitLevel(rms: Float) -> Double {
        let db = 20 * log10(max(rms, 0.000_01))
        return Double(min(1, max(0, (db + 50) / 40)))
    }
}

public struct CaptureSnapshot: Equatable {
    public var listening: Bool
    public var heardSpeech: Bool
    public var transcript: String
    public var quietFrames: Int
    public var outcome: String?

    public static let idle = CaptureSnapshot(
        listening: false, heardSpeech: false, transcript: "", quietFrames: 0, outcome: nil
    )
}

public enum CaptureEvent: Equatable {
    case begin
    case level(Double)
    case partial(String)
    case userStop
    case timeout
}

public enum CaptureMachine {
    public static let speechLevel = 0.18
    public static let quietLevel = 0.08
    /// Der Aufrufer schickt Pegel etwa zehnmal pro Sekunde. Sechs ruhige Frames sind etwas über eine halbe Sekunde nach Sprache.
    public static let quietFramesToStop = 6

    public static func reduce(_ state: CaptureSnapshot, _ event: CaptureEvent) -> CaptureSnapshot {
        if state.outcome != nil { return state }
        var next = state
        switch event {
        case .begin:
            return CaptureSnapshot(listening: true, heardSpeech: false, transcript: "", quietFrames: 0, outcome: nil)
        case .level(let level):
            guard next.listening else { return next }
            if level >= speechLevel {
                next.heardSpeech = true
                next.quietFrames = 0
            } else if next.heardSpeech, level < quietLevel {
                next.quietFrames += 1
                if next.quietFrames >= quietFramesToStop {
                    next.listening = false
                    next.outcome = next.transcript
                }
            }
        case .partial(let text):
            guard next.listening, !text.isEmpty else { return next }
            next.transcript = text
            next.quietFrames = 0
        case .userStop, .timeout:
            guard next.listening else { return next }
            next.listening = false
            next.outcome = next.transcript
        }
        return next
    }
}

public enum SpeechPace {
    /// Normal etwas unter dem Systemtempo, langsam knapp über dem Minimum.
    public static func rate(slow: Bool, minimum: Float, defaultRate: Float) -> Float {
        slow ? minimum + 0.15 : defaultRate * 0.9
    }

    /// Langsam trennt Wörter und legt dazwischen eine Pause. Eine Silbe bleibt ein Stück.
    public static func chunks(_ text: String, slow: Bool) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard slow, !trimmed.isEmpty else { return [trimmed] }
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
        return parts.count > 1 ? parts : [trimmed]
    }
}

public enum SpeechMatch {
    /// Längste zuerst, damit ครับผม vor ครับ fällt.
    public static let particleSuffixes = ["ครับผม", "นะครับ", "นะคะ", "นะค่ะ", "ครับ", "ค่ะ", "คะ", "คับ", "ค้า", "นะ", "จ้า", "จ้ะ", "จ๊ะ"]

    public static func normalize(_ text: String) -> String {
        var value = text.precomposedStringWithCanonicalMapping
        value = value.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "\u{200B}", with: "")
        return value
    }

    public static func stripParticles(_ text: String) -> String {
        var value = normalize(text)
        var changed = true
        while changed {
            changed = false
            for suffix in particleSuffixes where value.hasSuffix(suffix) && value.count > suffix.count {
                value.removeLast(suffix.count)
                changed = true
                break
            }
        }
        return value
    }

    public static func similarity(_ left: String, _ right: String) -> Double {
        if left == right { return 1 }
        if left.isEmpty || right.isEmpty { return 0 }
        let distance = levenshtein(left, right)
        let scale = Double(max(left.count, right.count))
        return 1 - (Double(distance) / scale)
    }

    /// On-Device-Erkennung liefert oft die Zeile ohne Partikel oder mit einem Leerzeichen.
    public static func accepts(recognized: String, expectedThai: String) -> Bool {
        let heard = normalize(recognized)
        let expected = normalize(expectedThai)
        guard !heard.isEmpty, !expected.isEmpty else { return false }
        if heard == expected { return true }
        let heardCore = stripParticles(heard)
        let expectedCore = stripParticles(expected)
        if !heardCore.isEmpty, heardCore == expectedCore { return true }
        if containsLoose(heardCore, expectedCore) { return true }
        return false
    }

    private static func containsLoose(_ heard: String, _ expected: String) -> Bool {
        guard heard.count >= 2, expected.count >= 2 else { return false }
        let short = heard.count < expected.count ? heard : expected
        let long = heard.count < expected.count ? expected : heard
        guard long.contains(short) else { return false }
        return Double(short.count) / Double(long.count) >= 0.85
    }

    static func levenshtein(_ left: String, _ right: String) -> Int {
        let a = Array(left)
        let b = Array(right)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}
