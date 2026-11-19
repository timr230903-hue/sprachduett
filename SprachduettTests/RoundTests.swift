import XCTest
@testable import SprachduettCore

final class RoundTests: XCTestCase {
    func testBundledPathCoversBeginners() throws {
        let units = LearningPath.load(from: try CatalogLoader.loadBundled())
        let words = units.flatMap(\.words)
        XCTAssertGreaterThanOrEqual(Set(words.map(\.id)).count, 150)
        XCTAssertEqual(units.filter { $0.stage == 1 }.map(\.id), ["a0-hallo", "a0-ja", "a0-zahlen", "a0-toene"])
        XCTAssertGreaterThanOrEqual(units.filter { $0.stage == 2 }.count, 6)
        XCTAssertTrue(words.allSatisfy { !$0.emoji.isEmpty && !$0.thai.isEmpty && !$0.roman.isEmpty })
        XCTAssertTrue(units.allSatisfy { $0.dialogs.count >= 2 })
    }

    func testUnlocksTheNextUnitAtEightyPercent() {
        let units = sampleUnits()
        var stats: [String: WordStat] = [:]
        XCTAssertEqual(LearningPath.currentIndex(units: units, stats: stats), 0)
        XCTAssertFalse(LearningPath.isUnlocked(1, units: units, stats: stats))
        for word in units[0].words {
            stats[word.id] = WordStat(id: word.id, reviews: 2, correct: 2, streak: 2)
        }
        XCTAssertGreaterThanOrEqual(LearningPath.ratio(units[0], stats: stats), 0.8)
        XCTAssertTrue(LearningPath.isUnlocked(1, units: units, stats: stats))
        XCTAssertEqual(LearningPath.snapshot(units: units, stats: stats).label, "Stufe 1 · Einheit 2 von 2")
    }

    func testEmptyPathStaysOnTheHomeLabel() {
        let snapshot = LearningPath.snapshot(units: [], stats: [:])
        XCTAssertEqual(snapshot.stage, 1)
        XCTAssertEqual(snapshot.unitCount, 0)
        let plan = RoundBuilder.build(units: [], stats: [:], seed: 1, together: true)
        XCTAssertTrue(plan.beats.isEmpty)
        XCTAssertNil(RoundEngine.beat(plan, RoundCursor()))
    }

    func testFreshRoundIntroducesBeforeItQuizzes() throws {
        let units = LearningPath.load(from: try CatalogLoader.loadBundled())
        let plan = RoundBuilder.build(units: units, stats: [:], seed: 7, together: true)
        XCTAssertTrue(RoundEngine.introsComeFirst(plan))
        let intros = plan.beats.compactMap { beat -> String? in
            if case .intro(let word) = beat { return word.id }
            return nil
        }
        XCTAssertFalse(intros.isEmpty)
        XCTAssertEqual(plan.unitTitle, "Hallo")
        XCTAssertTrue(plan.label.hasPrefix("Stufe 1"))
        if case .listen(let first) = plan.beats.first(where: { if case .listen = $0 { return true }; return false }) {
            XCTAssertTrue(intros.contains(first.answer.id))
            XCTAssertEqual(first.choices.count, 4)
            XCTAssertTrue(first.choices.contains { $0.id == first.answer.id })
        } else {
            XCTFail("keine Hör-Aufgabe")
        }
    }

    func testOnePhoneWhenThePartnerIsAway() {
        XCTAssertEqual(PlayMode.resolve(together: true, partnerConnected: false), .togetherOnePhone)
        XCTAssertEqual(PlayMode.resolve(together: true, partnerConnected: true), .twoPhones)
        XCTAssertEqual(PlayMode.resolve(together: false, partnerConnected: true), .solo)
    }

    func testFirstCorrectTapScoresAndAMissLetsTheOtherTry() {
        let word = PathWord(id: "w", emoji: "🍚", thai: "ข้าว", roman: "khâao", german: "Reis")
        let other = PathWord(id: "o", emoji: "🐔", thai: "ไก่", roman: "gài", german: "Huhn")
        let item = ListenChallenge(id: "q", answer: word, choices: [word, other])
        let plan = RoundPlan(beats: [.listen(item)], label: "Stufe 1 · Einheit 1 von 1", unitTitle: "Essen")
        var cursor = RoundCursor()
        let (waiting, none) = RoundEngine.listenTap(cursor, plan: plan, playerID: "p1", choiceID: "o", seats: ["p1", "p2"])
        XCTAssertNil(none)
        XCTAssertEqual(waiting.missed, ["p1"])
        XCTAssertEqual(waiting.index, 0)
        let (won, grade) = RoundEngine.listenTap(waiting, plan: plan, playerID: "p2", choiceID: "w", seats: ["p1", "p2"])
        XCTAssertEqual(grade?.playerID, "p2")
        XCTAssertEqual(won.scores["p2"], 1)
        XCTAssertTrue(won.finished)
        cursor = RoundCursor()
        let (bothMiss, miss) = RoundEngine.listenTap(cursor, plan: plan, playerID: "p1", choiceID: "o", seats: ["p1"])
        XCTAssertEqual(miss?.correct, false)
        XCTAssertTrue(bothMiss.finished)
        XCTAssertEqual(bothMiss.scores["p1"], nil)
    }

    func testSayAndDialogAwardTheSpeaker() {
        let word = PathWord(id: "w", emoji: "🙏", thai: "ขอบคุณ", roman: "khɔ̀ɔp-khun", german: "Danke")
        let line = SpokenBit(thai: "สวัสดี", roman: "sà-wàt-dii", german: "Hallo.")
        let plan = RoundPlan(beats: [
            .say(SayTurn(id: "s", word: word, speakerID: "p1")),
            .dialog(DialogTurn(id: "d", line: line, speakerID: "p2")),
        ], label: "", unitTitle: "")
        var cursor = RoundEngine.revealSay(RoundCursor(), plan: plan)
        XCTAssertEqual(cursor.phase, .check)
        let (afterSay, grade) = RoundEngine.judgeSay(cursor, plan: plan, correct: true)
        XCTAssertEqual(grade?.correct, true)
        XCTAssertEqual(afterSay.scores["p1"], 1)
        cursor = RoundEngine.confirmDialog(afterSay, plan: plan)
        XCTAssertEqual(cursor.scores["p2"], 1)
        XCTAssertTrue(cursor.finished)
        var stats: [String: WordStat] = [:]
        stats = RoundEngine.apply(stats, GradedWord(wordID: "w", correct: true, playerID: "p1"))
        stats = RoundEngine.apply(stats, GradedWord(wordID: "w", correct: true, playerID: "p1"))
        XCTAssertEqual(stats["w"]?.mastered, true)
        stats = RoundEngine.apply(stats, GradedWord(wordID: "w", correct: false, playerID: nil))
        XCTAssertEqual(stats["w"]?.mastered, false)
    }

    func testToneMarksKeepTheirArrows() {
        let sawat = RomanTones.syllables("sà-wàt-dii")
        XCTAssertEqual(sawat.map(\.tone), [.low, .low, .mid])
        XCTAssertEqual(RomanTones.tone(of: "mâi"), .falling)
        XCTAssertEqual(RomanTones.tone(of: "mái"), .high)
        XCTAssertEqual(RomanTones.tone(of: "mǎi"), .rising)
        XCTAssertEqual(RomanTones.tone(of: "bpai"), .mid)
        XCTAssertEqual(ToneColor.falling.arrow, "↓")
        XCTAssertEqual(ToneColor.rising.arrow, "↗")
    }

    private func sampleUnits() -> [LearnUnit] {
        let words = (1...4).map { PathWord(id: "a\($0)", emoji: "⭐", thai: "ก", roman: "gaa", german: "\($0)") }
        let more = [PathWord(id: "b1", emoji: "⭐", thai: "ข", roman: "khǎa", german: "Bein")]
        let dialog = DialogPair(
            id: "d",
            a: SpokenBit(thai: "ก", roman: "gaa", german: "a"),
            b: SpokenBit(thai: "ข", roman: "khǎa", german: "b")
        )
        return [
            LearnUnit(id: "one", stage: 1, title: "Eins", words: words, dialogs: [dialog, dialog]),
            LearnUnit(id: "two", stage: 1, title: "Zwei", words: more, dialogs: [dialog, dialog]),
        ]
    }
}
