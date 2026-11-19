import Foundation

public struct GuideCard: Equatable, Identifiable {
    public let id: String
    public let emoji: String
    public let title: String
    public let text: String

    public init(id: String, emoji: String, title: String, text: String) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.text = text
    }
}

public enum TutorialKey {
    public static let intro = "tutorial.intro.seen"
    public static let lesson = "tutorial.lesson.seen"
}

public enum TutorialScript {
    public static let pages: [GuideCard] = [
        GuideCard(
            id: "handy",
            emoji: "📱",
            title: "Ein Handy reicht",
            text: "Legt es zwischen euch. Eine Runde dauert ein paar Minuten. Koppeln könnt ihr später."
        ),
        GuideCard(
            id: "spiele",
            emoji: "🎲",
            title: "Drei kleine Spiele",
            text: "Erst hören und tippen, dann das Thai-Wort sagen, dann zwei Sätze vorlesen."
        ),
        GuideCard(
            id: "pfad",
            emoji: "🌱",
            title: "Von Hallo bis zum Alltag",
            text: "Ihr fangt bei null an. Eine Einheit öffnet die nächste, wenn ihr sie könnt."
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
        advance(index: index) == nil ? "Los geht's" : "Weiter"
    }
}

public enum LessonTour {
    public static let steps: [GuideCard] = [
        GuideCard(id: "intro", emoji: "👂", title: "Zuerst zuhören", text: "Neue Wörter hört ihr gemeinsam und sprecht sie nach. Danach kommt das Spiel."),
        GuideCard(id: "listen", emoji: "👆", title: "Wer tippt zuerst?", text: "Jede Seite hat dieselben Bilder. Der erste richtige Tipp bekommt den Punkt."),
        GuideCard(id: "say", emoji: "🗣️", title: "Sag das Wort", text: "Eine Person sieht nur das Bild. Die andere hört zu und tippt Richtig."),
        GuideCard(id: "dialog", emoji: "✅", title: "Zwei Sätze", text: "Lies deinen Satz laut vor. Die andere Person tippt Verstanden."),
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

    public func replay() -> TutorialProgress {
        TutorialProgress(introSeen: introSeen, lessonSeen: false)
    }
}
