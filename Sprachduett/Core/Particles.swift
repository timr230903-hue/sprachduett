import Foundation

public struct SpokenForm: Equatable {
    public let thai: String
    public let roman: String

    public init(thai: String, roman: String) {
        self.thai = thai
        self.roman = roman
    }
}

/// Höflichkeitspartikel nach Sprechergeschlecht.
/// ครับ wird als gesprochene hohe Partikel khráp gelehrt (Paiboon). Die Schreibung
/// allein ergäbe einen tiefen Ton; im höflichen Satz hört man den hohen.
public enum Particles {
    public static let maleThai = "ครับ"
    public static let maleRoman = "khráp"
    public static let femaleStatementThai = "ค่ะ"
    public static let femaleStatementRoman = "khâ"
    public static let femaleQuestionThai = "คะ"
    public static let femaleQuestionRoman = "khá"

    public static func apply(thai: String, roman: String, particle: ParticleKind, gender: SpeakerGender) -> SpokenForm {
        guard particle != .none else { return SpokenForm(thai: thai, roman: roman) }
        let suffix = suffixThai(particle, gender)
        let suffixRoman = suffixRoman(particle, gender)
        guard !suffix.isEmpty else { return SpokenForm(thai: thai, roman: roman) }
        let spokenThai = thai.hasSuffix(suffix) ? thai : thai + suffix
        let spokenRoman: String
        if roman.split(separator: " ").last?.description == suffixRoman {
            spokenRoman = roman
        } else {
            spokenRoman = roman + " " + suffixRoman
        }
        return SpokenForm(thai: spokenThai, roman: spokenRoman)
    }

    public static func suffixThai(_ particle: ParticleKind, _ gender: SpeakerGender) -> String {
        switch (particle, gender) {
        case (.none, _), (_, .unspecified):
            return ""
        case (.statement, .male), (.question, .male):
            return maleThai
        case (.statement, .female):
            return femaleStatementThai
        case (.question, .female):
            return femaleQuestionThai
        }
    }

    public static func suffixRoman(_ particle: ParticleKind, _ gender: SpeakerGender) -> String {
        switch (particle, gender) {
        case (.none, _), (_, .unspecified):
            return ""
        case (.statement, .male), (.question, .male):
            return maleRoman
        case (.statement, .female):
            return femaleStatementRoman
        case (.question, .female):
            return femaleQuestionRoman
        }
    }
}
