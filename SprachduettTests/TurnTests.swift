import XCTest
@testable import SprachduettCore

final class TurnTests: XCTestCase {
    private let scene = DuettScene(
        id: "probe",
        title: "Probe",
        setting: "Test",
        emoji: "🎤",
        roleA: "A",
        roleB: "B",
        lines: [
            DuettLine(id: "l1", role: .a, thai: "สวัสดี", roman: "sà-wàt-dii", german: "Hallo.", particle: .statement),
            DuettLine(id: "l2", role: .b, thai: "สบายดีไหม", roman: "sà-baai-dii mǎi", german: "Wie geht's?", particle: .question),
            DuettLine(id: "l3", role: .a, thai: "สบายดี", roman: "sà-baai-dii", german: "Gut.", particle: .statement),
        ]
    )

    private func fresh(passPhone: Bool, at date: Date = Date(timeIntervalSince1970: 10)) -> SessionSnapshot {
        SessionSnapshot(
            sceneID: "probe", cursor: 0, passedIDs: [], passPhone: passPhone, holder: .a,
            awaitingHandoff: passPhone, needsRepeat: false, updatedAt: date
        )
    }

    func testEachPhoneSeesOnlyItsOwnLine() {
        var session = fresh(passPhone: false)
        session.awaitingHandoff = false
        let mine = TurnEngine.view(scene: scene, snapshot: session, deviceRole: .a)
        XCTAssertEqual(mine.phase, .speak)
        XCTAssertTrue(mine.showsThai)
        XCTAssertEqual(mine.line?.thai, "สวัสดี")

        let theirs = TurnEngine.view(scene: scene, snapshot: session, deviceRole: .b)
        XCTAssertEqual(theirs.phase, .listen)
        XCTAssertFalse(theirs.showsThai)
        XCTAssertNil(theirs.line)
    }

    func testConfirmIgnoresTheWrongLineAndAdvances() {
        var session = fresh(passPhone: false)
        session.awaitingHandoff = false
        let ignored = TurnEngine.confirm(session, scene: scene, lineID: "l2", at: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(ignored, session)

        let next = TurnEngine.confirm(session, scene: scene, lineID: "l1", at: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(next.cursor, 1)
        XCTAssertEqual(next.passedIDs, ["l1"])
        let listener = TurnEngine.view(scene: scene, snapshot: next, deviceRole: .a)
        XCTAssertEqual(listener.phase, .listen)
        XCTAssertFalse(listener.showsThai)
        let speaker = TurnEngine.view(scene: scene, snapshot: next, deviceRole: .b)
        XCTAssertEqual(speaker.line?.id, "l2")
        XCTAssertTrue(speaker.showsThai)
    }

    func testPassPhoneHidesTheLineUntilTheHandoff() {
        let session = fresh(passPhone: true)
        let covered = TurnEngine.view(scene: scene, snapshot: session, deviceRole: .b)
        XCTAssertEqual(covered.phase, .handoff(.a))
        XCTAssertFalse(covered.showsThai)

        let open = TurnEngine.acceptHandoff(session, scene: scene, at: Date(timeIntervalSince1970: 11))
        XCTAssertEqual(open.holder, .a)
        XCTAssertFalse(open.awaitingHandoff)
        XCTAssertTrue(TurnEngine.view(scene: scene, snapshot: open, deviceRole: .b).showsThai)

        let after = TurnEngine.confirm(open, scene: scene, lineID: "l1", at: Date(timeIntervalSince1970: 12))
        XCTAssertTrue(after.awaitingHandoff)
        XCTAssertEqual(TurnEngine.view(scene: scene, snapshot: after, deviceRole: .a).phase, .handoff(.b))
    }

    func testRepeatAndRewind() {
        var session = fresh(passPhone: true)
        session = TurnEngine.acceptHandoff(session, scene: scene, at: Date(timeIntervalSince1970: 11))
        session = TurnEngine.confirm(session, scene: scene, lineID: "l1", at: Date(timeIntervalSince1970: 12))
        let asked = TurnEngine.requestRepeat(session, at: Date(timeIntervalSince1970: 13))
        XCTAssertTrue(asked.needsRepeat)
        XCTAssertEqual(asked.cursor, 1)

        let back = TurnEngine.rewind(session, scene: scene, at: Date(timeIntervalSince1970: 14))
        XCTAssertEqual(back.cursor, 0)
        XCTAssertEqual(back.passedIDs, [])
        XCTAssertEqual(back.holder, .a)
        XCTAssertTrue(back.awaitingHandoff)
        XCTAssertFalse(back.needsRepeat)
    }

    func testSceneCompletes() {
        var session = fresh(passPhone: false)
        session.awaitingHandoff = false
        for id in ["l1", "l2", "l3"] {
            session = TurnEngine.confirm(session, scene: scene, lineID: id, at: Date(timeIntervalSince1970: 30))
        }
        XCTAssertTrue(TurnEngine.isComplete(scene: scene, snapshot: session))
        XCTAssertEqual(TurnEngine.view(scene: scene, snapshot: session, deviceRole: .a).phase, .done)
    }

    func testMergeKeepsTheLongerPrefixAndNewerFlags() {
        let early = fresh(passPhone: false, at: Date(timeIntervalSince1970: 1))
        var later = early
        later.passedIDs = ["l1"]
        later.cursor = 1
        later.updatedAt = Date(timeIntervalSince1970: 2)
        XCTAssertEqual(TurnEngine.merge(early, later).passedIDs, ["l1"])

        var repeated = early
        repeated.needsRepeat = true
        repeated.updatedAt = Date(timeIntervalSince1970: 5)
        XCTAssertTrue(TurnEngine.merge(early, repeated).needsRepeat)

        var other = early
        other.sceneID = "andere"
        other.updatedAt = Date(timeIntervalSince1970: 9)
        XCTAssertEqual(TurnEngine.merge(early, other).sceneID, "andere")
    }
}
