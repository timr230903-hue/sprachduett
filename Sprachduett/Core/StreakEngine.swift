import Foundation

public struct PracticeStamp: Codable, Equatable, Hashable {
    public let userID: String
    public let day: String

    public init(userID: String, day: String) {
        self.userID = userID
        self.day = day
    }
}

public struct StreakStatus: Equatable {
    public let length: Int
    public let todayBoth: Bool
    public let practicedToday: Set<String>
    public let missingToday: Set<String>

    public init(length: Int, todayBoth: Bool, practicedToday: Set<String>, missingToday: Set<String>) {
        self.length = length
        self.todayBoth = todayBoth
        self.practicedToday = practicedToday
        self.missingToday = missingToday
    }
}

public enum DayKey {
    public static func string(from date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func previous(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return day }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = calendar.date(from: components),
              let prior = calendar.date(byAdding: .day, value: -1, to: date) else { return day }
        return string(from: prior, calendar: calendar)
    }
}

public enum StreakEngine {
    /// Ein Tag zählt nur, wenn jedes Mitglied an dem Tag gesprochen hat.
    /// Ist heute unvollständig, bleibt die Serie der abgeschlossenen Tage davor stehen.
    /// Mit genau einem Mitglied (Solo) zählt dessen eigenes Üben.
    public static func status(stamps: [PracticeStamp], members: [String], today: String) -> StreakStatus {
        let memberSet = Set(members.filter { !$0.isEmpty })
        guard !memberSet.isEmpty else {
            return StreakStatus(length: 0, todayBoth: false, practicedToday: [], missingToday: [])
        }
        let todaySet = practiced(on: today, stamps: stamps, members: memberSet)
        let todayBoth = todaySet == memberSet
        var length = 0
        var cursor = todayBoth ? today : DayKey.previous(today)
        var guardRail = 0
        while practiced(on: cursor, stamps: stamps, members: memberSet) == memberSet {
            length += 1
            let prior = DayKey.previous(cursor)
            if prior == cursor { break }
            cursor = prior
            guardRail += 1
            if guardRail > 5000 { break }
        }
        return StreakStatus(
            length: length,
            todayBoth: todayBoth,
            practicedToday: todaySet,
            missingToday: memberSet.subtracting(todaySet)
        )
    }

    private static func practiced(on day: String, stamps: [PracticeStamp], members: Set<String>) -> Set<String> {
        Set(stamps.filter { $0.day == day && members.contains($0.userID) }.map(\.userID))
    }
}
