import WidgetKit
import SwiftUI

/// Nicht im Xcode-Ziel. Erst einbinden, wenn die App Group und das Extension-Profil existieren.
struct WordEntry: TimelineEntry {
    let date: Date
    let thai: String
    let german: String
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), thai: "สวัสดี", german: "Hallo")
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60 * 12))))
    }
}

struct WordOfDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfDay", provider: WordProvider()) { entry in
            VStack(alignment: .leading) {
                Text(entry.thai).font(.headline)
                Text(entry.german).font(.caption)
            }
        }
        .configurationDisplayName("Wort des Tages")
        .description("Dasselbe Wort für euch beide.")
        .supportedFamilies([.systemSmall])
    }
}
