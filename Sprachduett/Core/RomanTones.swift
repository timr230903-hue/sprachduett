import Foundation

public enum ToneColor: String, Equatable {
    case mid, low, falling, high, rising

    public var arrow: String {
        switch self {
        case .mid: return "→"
        case .low: return "↘"
        case .falling: return "↓"
        case .high: return "↑"
        case .rising: return "↗"
        }
    }
}

public struct RomanSyllable: Equatable, Identifiable {
    public let text: String
    public let tone: ToneColor
    public var id: String { text + tone.rawValue }

    public init(text: String, tone: ToneColor) {
        self.text = text
        self.tone = tone
    }
}

public enum RomanTones {
    public static func syllables(_ roman: String) -> [RomanSyllable] {
        let pieces = roman.split { $0 == " " || $0 == "-" }.map(String.init).filter { !$0.isEmpty }
        return pieces.map { RomanSyllable(text: $0, tone: tone(of: $0)) }
    }

    public static func tone(of syllable: String) -> ToneColor {
        let decomposed = syllable.decomposedStringWithCanonicalMapping
        let marks = decomposed.unicodeScalars.map(\.value)
        if marks.contains(0x0302) { return .falling }
        if marks.contains(0x030C) { return .rising }
        if marks.contains(0x0301) { return .high }
        if marks.contains(0x0300) { return .low }
        return .mid
    }
}

/// Umschrift ist eine Krücke. A0 zeigt sie. Ab A1 blendet sie aus, sobald das Wort sitzt.
public enum RomanFade {
    public static func opacity(stage: Int, mastered: Bool, reviews: Int, pronunciation: Double, hidden: Bool) -> Double {
        if hidden { return 0 }
        guard stage >= 2 else { return 1 }
        if mastered { return 0 }
        if reviews <= 0 { return 1 }
        let practiced = min(Double(reviews), 6) / 6
        let known = min(max(pronunciation, 0), 1)
        return max(0, 1 - (practiced * 0.7 + known * 0.3))
    }
}
