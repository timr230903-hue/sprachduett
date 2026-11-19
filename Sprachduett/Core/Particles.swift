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

/// ผม/ฉัน und ครับ/ค่ะ/คะ passend zur Person, die gerade spricht.
public enum GenderVoice {
    private static let pronounsThai = ["ดิฉัน", "ผม", "ฉัน"]
    private static let pronounsRoman = ["dì-chǎn", "di-chan", "phǒm", "phom", "chǎn", "chan"]
    private static let social: [String] = [
        "สวัสดี", "ขอบคุณ", "ไม่เป็นไร", "ขอโทษ", "ใช่", "ไม่ใช่", "ได้", "ไม่ได้",
        "สบายดี", "ลาก่อน", "แล้วเจอกัน", "เชิญ", "ยินดีที่ได้รู้จัก", "กินข้าวยัง", "ฝันดี",
    ]

    public static func usesParticle(_ thai: String, dialog: Bool) -> Bool {
        if dialog { return true }
        return social.contains { thai.contains($0) }
    }

    public static func isQuestion(_ thai: String) -> Bool {
        ["ไหม", "มั้ย", "หรือ", "เหรอ"].contains { thai.contains($0) }
    }

    public static func speak(thai: String, roman: String, gender: SpeakerGender, polite: Bool) -> SpokenForm {
        let swapped = swap(thai: thai, roman: roman, gender: gender)
        let kind: ParticleKind
        if !polite || gender == .unspecified {
            kind = .none
        } else if isQuestion(swapped.thai) {
            kind = .question
        } else {
            kind = .statement
        }
        return Particles.apply(thai: swapped.thai, roman: swapped.roman, particle: kind, gender: gender)
    }

    private static func swap(thai: String, roman: String, gender: SpeakerGender) -> SpokenForm {
        guard gender != .unspecified else { return SpokenForm(thai: thai, roman: roman) }
        let pronoun = gender == .male ? "ผม" : "ฉัน"
        let pronounRoman = gender == .male ? "phǒm" : "chǎn"
        var nextThai = thai
        for item in pronounsThai where nextThai.contains(item) {
            nextThai = nextThai.replacingOccurrences(of: item, with: pronoun)
        }
        var nextRoman = roman
        for item in pronounsRoman where nextRoman.contains(item) {
            nextRoman = nextRoman.replacingOccurrences(of: item, with: pronounRoman)
        }
        if gender == .male, nextThai == "ค่ะ" || nextThai == "คะ" {
            nextThai = Particles.maleThai
            nextRoman = Particles.maleRoman
        }
        if gender == .female, nextThai == "ครับ" || nextThai == "คับ" {
            nextThai = Particles.femaleStatementThai
            nextRoman = Particles.femaleStatementRoman
        }
        return SpokenForm(thai: nextThai, roman: nextRoman)
    }
}
