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
        if bestBare >= 0.99 || bestFull >= 0.72 || bestBare >= 0.8 { return .close }
        return .miss
    }
}

public enum SpeechMatch {
    /// Längste zuerst, damit ครับผม vor ครับ fällt.
    public static let particleSuffixes = ["ครับผม", "นะครับ", "นะคะ", "ครับ", "ค่ะ", "คะ", "นะ", "จ้า", "จ้ะ"]

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
        return similarity(heardCore, expectedCore) >= 0.8
    }

    private static func containsLoose(_ heard: String, _ expected: String) -> Bool {
        guard heard.count >= 2, expected.count >= 2 else { return false }
        let short = heard.count < expected.count ? heard : expected
        let long = heard.count < expected.count ? expected : heard
        guard long.contains(short) else { return false }
        return Double(short.count) / Double(long.count) >= 0.6
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
