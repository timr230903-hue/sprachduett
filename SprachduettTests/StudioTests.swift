import XCTest
@testable import SprachduettCore

final class StudioTests: XCTestCase {
    func testOnlyThaiShipsAndClipsStayOptional() {
        XCTAssertEqual(LanguageLibrary.shipped, ["th"])
        let pack = ContentPacks.loadThai(catalog: ThaiCatalog(language: "th", title: "Thai", tones: [], topics: [], scenes: []))
        XCTAssertEqual(pack.language.speechLocale, "th-TH")
        XCTAssertEqual(pack.catalog.language, "th")
        XCTAssertEqual(ThaiLanguage().speechLocale, "th-TH")
        XCTAssertEqual(ClipLibrary.fileName(id: "pol-01"), "pol-01.m4a")
        XCTAssertTrue(ClipLibrary.prefersRecording(hasFile: true, slow: false))
        XCTAssertFalse(ClipLibrary.prefersRecording(hasFile: true, slow: true))
        XCTAssertFalse(ClipLibrary.prefersRecording(hasFile: false, slow: false))
    }

    func testToneDuelUsesRealMinimalPairs() {
        let rounds = ToneDuel.rounds(knownIDs: ["ton-06", "ton-07", "ton-08", "ton-02"])
        XCTAssertEqual(rounds.count, 1)
        XCTAssertFalse(ToneDuel.hit(promptID: "ton-06", choiceID: "ton-07"))
        XCTAssertTrue(ToneDuel.hit(promptID: "ton-06", choiceID: "ton-06"))
    }

    func testScriptUnlocksOneLessonADay() {
        XCTAssertEqual(ScriptCourse.unlockedCount(done: 0, lastDay: "", today: "2026-11-19"), 1)
        XCTAssertEqual(ScriptCourse.unlockedCount(done: 1, lastDay: "2026-11-19", today: "2026-11-19"), 1)
        XCTAssertEqual(ScriptCourse.unlockedCount(done: 1, lastDay: "2026-11-19", today: "2026-11-20"), 2)
        XCTAssertEqual(ScriptCourse.lessons[0].glyphs.count, 4)
        XCTAssertFalse(ScriptCourse.lessons[0].sign.isEmpty)
    }

    func testTravelIsOfflineAndSearchFindsGerman() {
        XCTAssertEqual(TravelDeck.places.map(\.id), ["taxi", "market", "doctor", "hotel"])
        XCTAssertTrue(TravelDeck.places.allSatisfy { $0.lines.count >= 3 })
        let hits = Phrasebook.search("wasser", phrases: [
            PhraseHit(id: "a", thai: "น้ำ", roman: "náam", german: "Wasser"),
            PhraseHit(id: "b", thai: "ข้าว", roman: "khâao", german: "Reis"),
        ])
        XCTAssertEqual(hits.map(\.id), ["a"])
        XCTAssertTrue(Phrasebook.search("w", phrases: [PhraseHit(id: "a", thai: "น้ำ", roman: "náam", german: "Wasser")]).isEmpty)
    }

    func testReminderDoesNotInventAStreakLoss() {
        XCTAssertFalse(CoupleReminder.shouldNudge(myID: "a", partnerID: nil, stamps: [], today: "2026-11-19"))
        XCTAssertTrue(CoupleReminder.shouldNudge(
            myID: "a", partnerID: "b",
            stamps: [("b", "2026-11-19")],
            today: "2026-11-19"
        ))
        XCTAssertFalse(CoupleReminder.shouldNudge(
            myID: "a", partnerID: "b",
            stamps: [("a", "2026-11-19"), ("b", "2026-11-19")],
            today: "2026-11-19"
        ))
        XCTAssertEqual(CoupleReminder.hour, 19)
        XCTAssertTrue(CoupleReminder.body.contains("jetzt du"))
    }

    func testQuestBuildHintAndVoices() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_763_600_000)
        XCTAssertFalse(PairQuest.weekKey(date, calendar: calendar).isEmpty)
        let open = PairQuest.record(rounds: 4, checks: 0, celebrated: false, addRound: true, addCheck: true)
        XCTAssertTrue(open.done)
        XCTAssertTrue(open.line.contains("5/5"))
        let built = BuildEngine.challenge(id: "s", thai: "เอา ข้าว", german: "Reis", together: true)
        XCTAssertEqual(built?.tokens.map(\.owner), ["p1", "p2"])
        XCTAssertEqual(BuildEngine.place([], token: 0), [0])
        XCTAssertNil(BuildEngine.place([], token: 1))
        XCTAssertTrue(BuildEngine.complete([0, 1], count: 2))
        let tone = SpeechHint.explain(recognized: "ก้า", expected: "กา", roman: "kâa")
        XCTAssertTrue(tone.message.contains("Ton"))
        XCTAssertEqual(tone.tone, .falling)
        let length = SpeechHint.explain(recognized: "น้ำา", expected: "น้ำ", roman: "náam")
        XCTAssertFalse(length.message.isEmpty)
        let kept = VoiceLibrary.merge(
            [VoiceClip(wordID: "a", ownerID: "p1", updatedAt: date, audioBase64: "old")],
            [VoiceClip(wordID: "a", ownerID: "p1", updatedAt: date.addingTimeInterval(10), audioBase64: "new")]
        )
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept[0].audioBase64, "new")
        XCTAssertEqual(RomanFade.opacity(stage: 2, mastered: true, reviews: 2, pronunciation: 0.4, hidden: false), 0)
    }

    func testShareCaptionAndDailyWordAreStable() {
        XCTAssertEqual(ProgressShare.caption("  Wir können jetzt bestellen. "), "Wir können jetzt bestellen.")
        XCTAssertEqual(ProgressShare.caption("  "), "Wir lernen Thai zusammen.")
        let day = "2026-11-19"
        XCTAssertEqual(WordOfDay.index(day: day, count: 10), WordOfDay.index(day: day, count: 10))
        XCTAssertEqual(WordOfDay.index(day: day, count: 0), 0)
        XCTAssertEqual(RolePlay.scenes.map(\.ambience), [.market, .massage, .tuktuk])
    }

    func testCoopListenScoresBothOnlyWhenSpeechAndPictureLand() throws {
        let word = PathWord(id: "w", emoji: "🍚", thai: "ข้าว", roman: "khâao", german: "Reis")
        let other = PathWord(id: "o", emoji: "🐔", thai: "ไก่", roman: "gài", german: "Huhn")
        let first = ListenChallenge(id: "a", answer: word, choices: [word, other], speakerID: "p1", listenerID: "p2", opensRound: true)
        let second = ListenChallenge(id: "b", answer: other, choices: [word, other], speakerID: "p2", listenerID: "p1", opensRound: false)
        let plan = RoundPlan(beats: [.listen(first), .listen(second)], label: "", unitTitle: "")
        var cursor = RoundEngine.prepare(RoundCursor(), plan: plan)
        XCTAssertEqual(cursor.listenPhase, .explain)
        cursor = RoundEngine.beginSpeaking(cursor, plan: plan)
        cursor = RoundEngine.noteSpeech(cursor, plan: plan, understood: true)
        XCTAssertEqual(cursor.listenPhase, .handoff)
        cursor = RoundEngine.confirmHandoff(cursor, plan: plan)
        let (scored, grade) = RoundEngine.point(cursor, plan: plan, choiceID: "w")
        XCTAssertEqual(grade?.correct, true)
        XCTAssertEqual(scored.scores["p1"], 1)
        XCTAssertEqual(scored.scores["p2"], 1)
        XCTAssertEqual(scored.listenPhase, .result)

        var missed = RoundEngine.prepare(RoundCursor(), plan: plan)
        missed = RoundEngine.beginSpeaking(missed, plan: plan)
        missed = RoundEngine.noteSpeech(missed, plan: plan, understood: false)
        missed = RoundEngine.confirmHandoff(missed, plan: plan)
        let (noPoint, bad) = RoundEngine.point(missed, plan: plan, choiceID: "w")
        XCTAssertEqual(bad?.correct, false)
        XCTAssertNil(noPoint.scores["p1"])
        let next = RoundEngine.prepare(RoundEngine.advance(scored, plan: plan), plan: plan)
        if case .listen(let item) = RoundEngine.beat(plan, next) {
            XCTAssertEqual(item.speakerID, "p2")
            XCTAssertEqual(item.listenerID, "p1")
            XCTAssertEqual(next.listenPhase, .speak)
        } else {
            XCTFail("zweite Runde")
        }
    }
}
