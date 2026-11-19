import Foundation

public enum PointsLedger {
    public static let linePoints = 10
    public static let sceneBonus = 50
    public static let duoDayBonus = 30

    public static func total(userID: String, confirmed: [ConfirmedLine], scenes: [DuettScene],
                             stamps: [PracticeStamp], members: [String]) -> Int {
        let mine = Set(confirmed.filter { $0.userID == userID }.map { "\($0.sceneID)|\($0.lineID)" })
        var points = mine.count * linePoints
        for scene in scenes {
            let spokenHere = scene.lines.contains { mine.contains("\(scene.id)|\($0.id)") }
            let finished = scene.lines.allSatisfy { line in
                confirmed.contains { $0.sceneID == scene.id && $0.lineID == line.id }
            }
            if spokenHere && finished {
                points += sceneBonus
            }
        }
        guard members.count >= 2 else { return points }
        let days = Set(stamps.filter { $0.userID == userID }.map(\.day))
        for day in days {
            let who = Set(stamps.filter { $0.day == day }.map(\.userID))
            if Set(members).isSubset(of: who) {
                points += duoDayBonus
            }
        }
        return points
    }
}

public struct ConfirmedLine: Codable, Equatable, Hashable {
    public var sceneID: String
    public var lineID: String
    public var userID: String
    public var day: String

    public init(sceneID: String, lineID: String, userID: String, day: String) {
        self.sceneID = sceneID
        self.lineID = lineID
        self.userID = userID
        self.day = day
    }
}
