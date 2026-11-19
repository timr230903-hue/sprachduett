import Foundation

public struct GuideCard: Equatable, Identifiable {
    public let id: String
    public let emoji: String
    public let title: String
    public let text: String
    public let asksForSpeech: Bool

    public init(id: String, emoji: String, title: String, text: String, asksForSpeech: Bool = false) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.text = text
        self.asksForSpeech = asksForSpeech
    }
}

public enum TutorialKey {
    public static let intro = "tutorial.intro.seen"
    public static let lesson = "tutorial.lesson.seen"
}

public enum TutorialScript {
    public static let pages: [GuideCard] = [
        GuideCard(
            id: "zusammen",
            emoji: "🗣️",
            title: "Zwei Stimmen",
            text: "Ihr lernt Thai zusammen. Laut, zueinander. Nicht still ins Handy starren."
        ),
        GuideCard(
            id: "duo",
            emoji: "🔗",
            title: "Ein Duo",
            text: "Eine Person erstellt das Duo und schickt den Link. Die andere tippt den Link und ist dabei."
        ),
        GuideCard(
            id: "zeile",
            emoji: "🎤",
            title: "Nur deine Zeile",
            text: "Jedes Handy zeigt nur die eigenen Sätze. Du sagst sie laut. Die Erkennung hört zu. Wenn sie aussetzt, tippt dein Partner Verstanden.",
            asksForSpeech: true
        ),
        GuideCard(
            id: "toene",
            emoji: "🎵",
            title: "Fünf Töne",
            text: "Mittel, tief, fallend, hoch, steigend. ไป ใหม่ ไม่ ไม้ ไหม. Der Ton ändert das Wort."
        ),
        GuideCard(
            id: "serie",
            emoji: "🔥",
            title: "Eure Serie",
            text: "Der Tag zählt nur, wenn ihr beide eine Zeile gesagt habt. Eine Stimme allein hält die Serie nicht."
        ),
        GuideCard(
            id: "zimmer",
            emoji: "📱",
            title: "Ein Handy im Zimmer",
            text: "Gebt das Gerät weiter. Die nächste Zeile bleibt zu, bis die richtige Person es in der Hand hat."
        ),
    ]

    public static func page(at index: Int) -> GuideCard? {
        guard pages.indices.contains(index) else { return nil }
        return pages[index]
    }

    public static func advance(index: Int) -> Int? {
        let next = index + 1
        return next < pages.count ? next : nil
    }

    public static func buttonTitle(index: Int) -> String {
        guard let page = page(at: index) else { return "Weiter" }
        if page.asksForSpeech { return "Erlauben und weiter" }
        if advance(index: index) == nil { return "Los geht's" }
        return "Weiter"
    }
}

public enum LessonTour {
    public static let steps: [GuideCard] = [
        GuideCard(
            id: "zeile",
            emoji: "👀",
            title: "Das ist deine Zeile",
            text: "Thai, Umschrift, Bedeutung. Dein Partner sieht diesen Text nicht."
        ),
        GuideCard(
            id: "hoeren",
            emoji: "🔊",
            title: "Erst anhören",
            text: "Hör die Zeile an. Dann schau deinen Partner an und sag sie laut."
        ),
        GuideCard(
            id: "pruefen",
            emoji: "✅",
            title: "Laut sagen",
            text: "Die Erkennung prüft die Zeile. Klappt sie nicht, tippt dein Partner Verstanden."
        ),
    ]

    public static func advance(step: Int) -> Int? {
        let next = step + 1
        return next < steps.count ? next : nil
    }

    public static func buttonTitle(step: Int) -> String {
        advance(step: step) == nil ? "Los" : "Weiter"
    }
}

public struct TutorialProgress: Equatable {
    public var introSeen: Bool
    public var lessonSeen: Bool

    public init(introSeen: Bool, lessonSeen: Bool) {
        self.introSeen = introSeen
        self.lessonSeen = lessonSeen
    }

    public var showsIntro: Bool { !introSeen }
    public var showsLessonCoach: Bool { !lessonSeen }

    public func finishIntro() -> TutorialProgress {
        TutorialProgress(introSeen: true, lessonSeen: lessonSeen)
    }

    public func finishLesson() -> TutorialProgress {
        TutorialProgress(introSeen: introSeen, lessonSeen: true)
    }

    /// Die Seiten noch einmal, und beim nächsten Duett wieder die Hinweise.
    public func replay() -> TutorialProgress {
        TutorialProgress(introSeen: introSeen, lessonSeen: false)
    }
}
