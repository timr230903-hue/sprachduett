import Foundation

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
