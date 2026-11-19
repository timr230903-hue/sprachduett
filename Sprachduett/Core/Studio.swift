import Foundation

public protocol LanguageContent {
    var code: String { get }
    var speechLocale: String { get }
    var title: String { get }
}

public struct ThaiLanguage: LanguageContent, Equatable {
    public let code = "th"
    public let speechLocale = "th-TH"
    public let title = "Thai"
    public init() {}
}

public enum LanguageLibrary {
    public static let shipped: [String] = ["th"]

    public static func contains(_ code: String) -> Bool {
        shipped.contains(code)
    }
}

public enum ClipLibrary {
    public static func fileName(id: String) -> String { "\(id).m4a" }

    /// Eine Aufnahme ersetzt die Stimme nur im normalen Tempo. Langsam bleibt die Synthese.
    public static func prefersRecording(hasFile: Bool, slow: Bool) -> Bool {
        hasFile && !slow
    }
}

public struct ToneRound: Equatable, Identifiable {
    public let id: String
    public let promptID: String
    public let optionIDs: [String]

    public init(id: String, promptID: String, optionIDs: [String]) {
        self.id = id
        self.promptID = promptID
        self.optionIDs = optionIDs
    }
}

public enum ToneDuel {
    public static let groups: [[String]] = [
        ["ton-02", "ton-03", "ton-04", "ton-05"],
        ["ton-06", "ton-07", "ton-08"],
        ["ton-09", "ton-11", "ton-12"],
    ]

    public static func rounds(knownIDs: Set<String>) -> [ToneRound] {
        groups.enumerated().compactMap { offset, group in
            let ids = group.filter { knownIDs.contains($0) }
            guard ids.count >= 2 else { return nil }
            return ToneRound(id: "tone-\(offset)", promptID: ids[0], optionIDs: ids)
        }
    }

    public static func hit(promptID: String, choiceID: String) -> Bool {
        promptID == choiceID
    }
}

public struct ScriptGlyph: Equatable, Identifiable {
    public let glyph: String
    public let name: String
    public let roman: String
    public var id: String { glyph }

    public init(glyph: String, name: String, roman: String) {
        self.glyph = glyph
        self.name = name
        self.roman = roman
    }
}

public struct ScriptLesson: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let glyphs: [ScriptGlyph]
    public let sign: String
    public let signRoman: String
    public let signGerman: String

    public init(id: String, title: String, glyphs: [ScriptGlyph], sign: String, signRoman: String, signGerman: String) {
        self.id = id
        self.title = title
        self.glyphs = glyphs
        self.sign = sign
        self.signRoman = signRoman
        self.signGerman = signGerman
    }
}

public enum ScriptCourse {
    public static let lessons: [ScriptLesson] = [
        ScriptLesson(
            id: "s1", title: "Mitten",
            glyphs: [
                ScriptGlyph(glyph: "ก", name: "kài", roman: "gài"),
                ScriptGlyph(glyph: "จ", name: "jaan", roman: "jaan"),
                ScriptGlyph(glyph: "ด", name: "dèk", roman: "dèk"),
                ScriptGlyph(glyph: "บ", name: "bai-mái", roman: "bai-mái"),
            ],
            sign: "ตลาด", signRoman: "dtà-làat", signGerman: "Markt"
        ),
        ScriptLesson(
            id: "s2", title: "Hoch",
            glyphs: [
                ScriptGlyph(glyph: "ข", name: "khài", roman: "khài"),
                ScriptGlyph(glyph: "ฉ", name: "chìng", roman: "chìng"),
                ScriptGlyph(glyph: "ถ", name: "thǔng", roman: "thǔng"),
                ScriptGlyph(glyph: "ผ", name: "phǔeng", roman: "phǔeng"),
            ],
            sign: "ห้องน้ำ", signRoman: "hông-náam", signGerman: "Toilette"
        ),
        ScriptLesson(
            id: "s3", title: "Tief",
            glyphs: [
                ScriptGlyph(glyph: "ค", name: "khwaai", roman: "khwaai"),
                ScriptGlyph(glyph: "ช", name: "cháang", roman: "cháang"),
                ScriptGlyph(glyph: "ม", name: "máa", roman: "máa"),
                ScriptGlyph(glyph: "ร", name: "rüa", roman: "rüa"),
            ],
            sign: "ข้าว", signRoman: "khâao", signGerman: "Reis"
        ),
    ]

    public static func unlockedCount(done: Int, lastDay: String, today: String) -> Int {
        let finishedToday = !lastDay.isEmpty && lastDay == today
        let next = finishedToday ? done : done + 1
        return min(max(next, 0), lessons.count)
    }
}

public struct TravelLine: Equatable, Identifiable {
    public let id: String
    public let thai: String
    public let roman: String
    public let german: String

    public init(id: String, thai: String, roman: String, german: String) {
        self.id = id
        self.thai = thai
        self.roman = roman
        self.german = german
    }
}

public struct TravelPlace: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let lines: [TravelLine]

    public init(id: String, title: String, lines: [TravelLine]) {
        self.id = id
        self.title = title
        self.lines = lines
    }
}

public enum TravelDeck {
    public static let places: [TravelPlace] = [
        TravelPlace(id: "taxi", title: "Taxi", lines: [
            TravelLine(id: "tx-1", thai: "ไปสยามได้ไหม", roman: "bpai siam dâai mǎi", german: "Nach Siam, geht das?"),
            TravelLine(id: "tx-2", thai: "เท่าไหร่", roman: "thâo-rài", german: "Was kostet das?"),
            TravelLine(id: "tx-3", thai: "จอดตรงนี้", roman: "jòt dtrong-níi", german: "Hier halten."),
        ]),
        TravelPlace(id: "market", title: "Markt", lines: [
            TravelLine(id: "mk-1", thai: "อันนี้เท่าไหร่", roman: "an-níi thâo-rài", german: "Was kostet das?"),
            TravelLine(id: "mk-2", thai: "แพงไป", roman: "phaeng bpai", german: "Zu teuer."),
            TravelLine(id: "mk-3", thai: "เอาอันนี้", roman: "ao an-níi", german: "Ich nehme das."),
        ]),
        TravelPlace(id: "doctor", title: "Arzt", lines: [
            TravelLine(id: "dr-1", thai: "ปวดหัว", roman: "bpùat hǔa", german: "Ich habe Kopfschmerzen."),
            TravelLine(id: "dr-2", thai: "ขอยา", roman: "khɔ̌ɔ yaa", german: "Medizin, bitte."),
            TravelLine(id: "dr-3", thai: "โรงพยาบาล", roman: "roong-phá-yaa-baan", german: "Krankenhaus"),
        ]),
        TravelPlace(id: "hotel", title: "Hotel", lines: [
            TravelLine(id: "ht-1", thai: "เช็คอิน", roman: "chék-in", german: "Einchecken"),
            TravelLine(id: "ht-2", thai: "ห้องน้ำอยู่ไหน", roman: "hông-náam yùu nǎi", german: "Wo ist die Toilette?"),
            TravelLine(id: "ht-3", thai: "น้ำร้อน", roman: "náam-ráwn", german: "warmes Wasser"),
        ]),
    ]
}

public struct PhraseHit: Equatable, Identifiable {
    public let id: String
    public let thai: String
    public let roman: String
    public let german: String

    public init(id: String, thai: String, roman: String, german: String) {
        self.id = id
        self.thai = thai
        self.roman = roman
        self.german = german
    }
}

public struct OwnCard: Codable, Equatable, Identifiable {
    public var id: String
    public var german: String
    public var thai: String
    public var roman: String
    public var audioName: String?

    public init(id: String, german: String, thai: String, roman: String, audioName: String? = nil) {
        self.id = id
        self.german = german
        self.thai = thai
        self.roman = roman
        self.audioName = audioName
    }
}

public enum Phrasebook {
    public static func search(_ query: String, phrases: [PhraseHit]) -> [PhraseHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count >= 2 else { return [] }
        return phrases.filter { $0.german.lowercased().contains(needle) || $0.thai.contains(needle) }
    }
}

public enum CoupleReminder {
    public static let hour = 19
    public static let body = "Partner hat heute schon gespielt, jetzt du?"

    public static func shouldNudge(myID: String, partnerID: String?, stamps: [(String, String)], today: String) -> Bool {
        guard let partnerID, partnerID != myID else { return false }
        let mine = stamps.contains { $0.0 == myID && $0.1 == today }
        let theirs = stamps.contains { $0.0 == partnerID && $0.1 == today }
        return theirs && !mine
    }
}

public enum AmbienceKind: String, Equatable, CaseIterable, Identifiable {
    case market, massage, tuktuk
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .market: return "Markt"
        case .massage: return "Massage"
        case .tuktuk: return "Tuk-Tuk"
        }
    }
}

public struct RoleScene: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let ambience: AmbienceKind
    public let line: TravelLine

    public init(id: String, title: String, ambience: AmbienceKind, line: TravelLine) {
        self.id = id
        self.title = title
        self.ambience = ambience
        self.line = line
    }
}

public enum RolePlay {
    public static let scenes: [RoleScene] = [
        RoleScene(id: "rp-market", title: "Am Stand", ambience: .market, line: TravelDeck.places[1].lines[0]),
        RoleScene(id: "rp-massage", title: "In der Massage", ambience: .massage, line: TravelLine(id: "ms-1", thai: "เบาได้ไหม", roman: "bao dâai mǎi", german: "Etwas sanfter?")),
        RoleScene(id: "rp-tuktuk", title: "Im Tuk-Tuk", ambience: .tuktuk, line: TravelDeck.places[0].lines[2]),
    ]
}

public enum ProgressShare {
    public static func caption(_ sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Wir lernen Thai zusammen." }
        return trimmed
    }
}

public enum WordOfDay {
    public static func index(day: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash = 5381
        for scalar in day.unicodeScalars {
            hash = hash &* 33 &+ Int(scalar.value)
        }
        let positive = hash == Int.min ? 0 : abs(hash)
        return positive % count
    }
}
