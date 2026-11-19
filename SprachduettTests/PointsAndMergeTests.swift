import XCTest
@testable import SprachduettCore

final class PointsAndMergeTests: XCTestCase {
    private let scenes = [
        DuettScene(
            id: "probe", title: "Probe", setting: "", emoji: "", roleA: "A", roleB: "B",
            lines: [
                DuettLine(id: "l1", role: .a, thai: "ไป", roman: "bpai", german: "gehen", particle: .none),
                DuettLine(id: "l2", role: .b, thai: "มา", roman: "maa", german: "kommen", particle: .none),
            ]
        )
    ]

    func testPointsCountALineOnceAndPayTheDuoBonus() {
        let confirmed = [
            ConfirmedLine(sceneID: "probe", lineID: "l1", userID: "tim", day: "2026-11-19"),
            ConfirmedLine(sceneID: "probe", lineID: "l1", userID: "tim", day: "2026-11-20"),
            ConfirmedLine(sceneID: "probe", lineID: "l2", userID: "mia", day: "2026-11-19"),
        ]
        let stamps = [
            PracticeStamp(userID: "tim", day: "2026-11-19"),
            PracticeStamp(userID: "mia", day: "2026-11-19"),
        ]
        let tim = PointsLedger.total(
            userID: "tim", confirmed: confirmed, scenes: scenes, stamps: stamps, members: ["tim", "mia"]
        )
        XCTAssertEqual(tim, PointsLedger.linePoints + PointsLedger.sceneBonus + PointsLedger.duoDayBonus)
        let solo = PointsLedger.total(
            userID: "tim", confirmed: confirmed, scenes: scenes, stamps: stamps, members: ["tim"]
        )
        XCTAssertEqual(solo, PointsLedger.linePoints + PointsLedger.sceneBonus)
    }

    func testMergeUnionsPracticeAndKeepsTheLongerScene() {
        let early = Date(timeIntervalSince1970: 1)
        let later = Date(timeIntervalSince1970: 2)
        let local = DuoCloudState(
            duoID: "duo",
            title: "Wir",
            members: [MemberProfile(id: "tim", name: "Tim", gender: .male, emoji: "🐘", role: .a)],
            stamps: [PracticeStamp(userID: "tim", day: "2026-11-19")],
            confirmed: [ConfirmedLine(sceneID: "probe", lineID: "l1", userID: "tim", day: "2026-11-19")],
            session: SessionSnapshot(
                sceneID: "probe", cursor: 1, passedIDs: ["l1"], passPhone: false, holder: .a,
                awaitingHandoff: false, needsRepeat: false, updatedAt: later
            ),
            updatedAt: early
        )
        let remote = DuoCloudState(
            duoID: "duo",
            title: "Duett",
            members: [MemberProfile(id: "mia", name: "Mia", gender: .female, emoji: "🌷", role: .b)],
            stamps: [PracticeStamp(userID: "mia", day: "2026-11-19")],
            confirmed: [ConfirmedLine(sceneID: "probe", lineID: "l2", userID: "mia", day: "2026-11-19")],
            session: SessionSnapshot(
                sceneID: "probe", cursor: 0, passedIDs: [], passPhone: false, holder: .a,
                awaitingHandoff: false, needsRepeat: true, updatedAt: early
            ),
            updatedAt: later
        )
        let merged = DuoMerge.merge(local, remote)
        XCTAssertEqual(merged.title, "Duett")
        XCTAssertEqual(Set(merged.members.map(\.id)), ["tim", "mia"])
        XCTAssertEqual(merged.stamps.count, 2)
        XCTAssertEqual(merged.confirmed.count, 2)
        XCTAssertEqual(merged.session?.passedIDs, ["l1"])
        XCTAssertEqual(merged.updatedAt, later)
    }

    func testDifferentDuosDoNotMix() {
        let older = DuoCloudState(
            duoID: "eins", title: "Alt", members: [], stamps: [PracticeStamp(userID: "tim", day: "2026-11-19")],
            confirmed: [], session: nil, updatedAt: Date(timeIntervalSince1970: 1)
        )
        let newer = DuoCloudState(
            duoID: "zwei", title: "Neu", members: [], stamps: [],
            confirmed: [], session: nil, updatedAt: Date(timeIntervalSince1970: 5)
        )
        let merged = DuoMerge.merge(older, newer)
        XCTAssertEqual(merged.duoID, "zwei")
        XCTAssertTrue(merged.stamps.isEmpty)
    }
}
