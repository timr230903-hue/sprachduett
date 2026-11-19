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
