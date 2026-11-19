import Foundation

public enum SpeakerGender: String, Codable, CaseIterable, Equatable {
    case male
    case female
    case unspecified
}

public enum ParticleKind: String, Codable, Equatable {
    case none
    case statement
    case question
}

public enum DuettRole: String, Codable, Equatable, CaseIterable {
    case a
    case b

    public var other: DuettRole { self == .a ? .b : .a }
}

public struct ToneLesson: Codable, Equatable, Identifiable {
    public let id: String
    public let nameDE: String
    public let nameTH: String
    public let roman: String
    public let mark: String
    public let contour: String
    public let exampleThai: String
    public let exampleRoman: String
    public let exampleDE: String
    public let rule: String
}

public struct Phrase: Codable, Equatable, Identifiable {
    public let id: String
    public let thai: String
    public let roman: String
    public let german: String
    public let particle: ParticleKind
}

public struct Topic: Codable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let blurb: String
    public let items: [Phrase]
}

public struct DuettLine: Codable, Equatable, Identifiable {
    public let id: String
    public let role: DuettRole
    public let thai: String
    public let roman: String
    public let german: String
    public let particle: ParticleKind
}

public struct DuettScene: Codable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let setting: String
    public let emoji: String
    public let roleA: String
    public let roleB: String
    public let lines: [DuettLine]

    public func roleTitle(_ role: DuettRole) -> String {
        role == .a ? roleA : roleB
    }
}

public struct ThaiCatalog: Codable, Equatable {
    public let language: String
    public let title: String
    public let tones: [ToneLesson]
    public let topics: [Topic]
    public let scenes: [DuettScene]

    public var phrases: [Phrase] { topics.flatMap(\.items) }
    public var phraseCount: Int { phrases.count }

    public func scene(_ id: String) -> DuettScene? {
        scenes.first { $0.id == id }
    }
}

public struct CatalogIssue: Error, Equatable, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public enum CatalogLoader {
    public static func decode(_ data: Data) throws -> ThaiCatalog {
        let catalog = try JSONDecoder().decode(ThaiCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    public static func loadBundled() throws -> ThaiCatalog {
        try load(from: CoreBundle.current)
    }

    public static func load(from bundle: Bundle) throws -> ThaiCatalog {
        let url = bundle.url(forResource: "thai", withExtension: "json")
            ?? bundle.url(forResource: "thai", withExtension: "json", subdirectory: "Resources")
        guard let url else { throw CatalogIssue("thai.json liegt nicht im Bundle.") }
        return try decode(Data(contentsOf: url))
    }
}

enum CoreBundle {
    static var current: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}

extension ThaiCatalog {
    public func validate() throws {
        guard language == "th" else { throw CatalogIssue("Sprache ist nicht th.") }
        guard tones.count == 5 else { throw CatalogIssue("Es braucht genau 5 Töne, nicht \(tones.count).") }
        try requireUnique(tones.map(\.id), label: "Ton")
        for tone in tones {
            try requireThai(tone.exampleThai, id: tone.id)
            try requireText(tone.exampleRoman, id: tone.id, field: "exampleRoman")
            try requireText(tone.rule, id: tone.id, field: "rule")
        }
        guard phraseCount >= 300 else { throw CatalogIssue("Nur \(phraseCount) Wörter, mindestens 300.") }
        try requireUnique(phrases.map(\.id), label: "Phrase")
        for phrase in phrases {
            try requireThai(phrase.thai, id: phrase.id)
            try requireText(phrase.roman, id: phrase.id, field: "roman")
            try requireText(phrase.german, id: phrase.id, field: "german")
        }
        guard scenes.count >= 12 else { throw CatalogIssue("Nur \(scenes.count) Szenen, mindestens 12.") }
        try requireUnique(scenes.map(\.id), label: "Szene")
        var lineIDs: [String] = []
        for scene in scenes {
            guard scene.lines.count >= 6 else {
                throw CatalogIssue("Szene \(scene.id) hat nur \(scene.lines.count) Zeilen.")
            }
            let roles = Set(scene.lines.map(\.role))
            guard roles.contains(.a), roles.contains(.b) else {
                throw CatalogIssue("Szene \(scene.id) braucht beide Rollen.")
            }
            for line in scene.lines {
                try requireThai(line.thai, id: line.id)
                try requireText(line.roman, id: line.id, field: "roman")
                try requireText(line.german, id: line.id, field: "german")
                lineIDs.append(line.id)
            }
        }
        try requireUnique(lineIDs, label: "Zeile")
    }

    private func requireUnique(_ ids: [String], label: String) throws {
        var seen = Set<String>()
        for id in ids {
            guard !id.isEmpty else { throw CatalogIssue("\(label) ohne ID.") }
            guard seen.insert(id).inserted else { throw CatalogIssue("Doppelte \(label)-ID \(id).") }
        }
    }

    private func requireThai(_ text: String, id: String) throws {
        guard text.unicodeScalars.contains(where: { (0x0E00...0x0E7F).contains($0.value) }) else {
            throw CatalogIssue("\(id) enthält kein Thai.")
        }
    }

    private func requireText(_ text: String, id: String, field: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogIssue("\(id).\(field) ist leer.")
        }
    }
}
