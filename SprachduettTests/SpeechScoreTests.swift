import XCTest
@testable import SprachduettCore

final class SpeechScoreTests: XCTestCase {
    func testExactAndParticleAreSure() {
        XCTAssertEqual(SpeechScore.grade(recognized: "สวัสดี", expected: "สวัสดี"), .sure)
        XCTAssertEqual(SpeechScore.grade(recognized: "สวัสดีครับ", expected: "สวัสดี"), .sure)
        XCTAssertEqual(SpeechScore.grade(recognized: "เอาผัดไทย", expected: "ผัดไทย", alternates: ["เอาผัดไทย"]), .sure)
    }

    func testToneMarkDifferenceIsCloseNotSure() {
        let mid = "กา"
        let falling = "ก้า"
        XCTAssertEqual(SpeechScore.withoutTones(falling), SpeechScore.withoutTones(mid))
        XCTAssertEqual(SpeechScore.grade(recognized: falling, expected: mid), .close)
    }

    func testUnrelatedIsMiss() {
        XCTAssertEqual(SpeechScore.grade(recognized: "น้ำ", expected: "ข้าว"), .miss)
        XCTAssertEqual(SpeechScore.grade(recognized: "", expected: "สวัสดี"), .miss)
        XCTAssertEqual(SpeechScore.grade(recognized: "เอ่อ", expected: "สวัสดี"), .miss)
        XCTAssertEqual(SpeechScore.grade(recognized: "อ่ะ", expected: "ขอบคุณครับ"), .miss)
        XCTAssertEqual(SpeechScore.grade(recognized: "แมว", expected: "หมา"), .miss)
        XCTAssertFalse(SpeechMatch.accepts(recognized: "ไอ", expectedThai: "สวัสดี"))
    }

    func testSlowRateIsClearlySlower() {
        let slow = SpeechPace.rate(slow: true, minimum: 0, defaultRate: 0.5)
        let normal = SpeechPace.rate(slow: false, minimum: 0, defaultRate: 0.5)
        XCTAssertEqual(normal, 0.45, accuracy: 0.001)
        XCTAssertEqual(slow, 0.15, accuracy: 0.001)
        XCTAssertLessThan(slow, normal * 0.5)
        XCTAssertEqual(SpeechPace.chunks("เอา ข้าว", slow: true), ["เอา", "ข้าว"])
        XCTAssertEqual(SpeechPace.chunks("สวัสดี", slow: true), ["สวัสดี"])
        XCTAssertEqual(SpeechPace.chunks("เอา ข้าว", slow: false), ["เอา ข้าว"])
    }

    func testLiveTokensLightAPrefixAndMarkAMiss() {
        let prefix = SpeechScore.liveTokens(recognized: "สวั", expected: "สวัสดี", roman: "sà-wàt-dii", finished: false)
        XCTAssertEqual(prefix.first?.light, .sure)
        XCTAssertTrue(prefix.contains { $0.light == .pending })
        let wrong = SpeechScore.liveTokens(recognized: "แมว", expected: "สวัสดี", roman: "sà-wàt-dii", finished: true)
        XCTAssertTrue(wrong.allSatisfy { $0.light == .miss })
        let quiet = SpeechScore.liveTokens(recognized: "", expected: "สวัสดี", roman: "sà-wàt-dii", finished: false)
        XCTAssertTrue(quiet.allSatisfy { $0.light == .pending })
        let done = SpeechScore.liveTokens(recognized: "สวัสดีครับ", expected: "สวัสดี", roman: "sà-wàt-dii", finished: true)
        XCTAssertTrue(done.allSatisfy { $0.light == .sure })
    }

    func testRestaurantOutcomeAndMonthlyGate() {
        let grades: [(String, SpeechGrade)] = [
            ("etwas zu essen bestellen", .sure),
            ("nach dem Preis fragen", .close),
            ("Danke sagen", .miss),
        ]
        let heard: [(String, Bool)] = [("einen Preis verstehen", true)]
        let outcome = RealLifeCheck.outcome(grades: grades, comprehension: heard)
        XCTAssertTrue(outcome.achieved.contains("etwas zu essen bestellen"))
        XCTAssertTrue(outcome.achieved.contains("nach dem Preis fragen"))
        XCTAssertTrue(outcome.achieved.contains("einen Preis verstehen"))
        XCTAssertTrue(outcome.missing.contains("Danke sagen"))
        XCTAssertTrue(outcome.sentence.contains("Bangkok"))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(RealLifeCheck.isDue(stageMastered: false, last: nil, now: now))
        XCTAssertTrue(RealLifeCheck.isDue(stageMastered: true, last: nil, now: now))
        XCTAssertFalse(RealLifeCheck.isDue(stageMastered: true, last: now.addingTimeInterval(-5 * 24 * 3600), now: now))
        XCTAssertTrue(RealLifeCheck.isDue(stageMastered: true, last: now.addingTimeInterval(-40 * 24 * 3600), now: now))
        XCTAssertGreaterThanOrEqual(RealLifeCheck.steps(level: 1).count, 4)
        XCTAssertGreaterThanOrEqual(RealLifeCheck.steps(level: 2).count, 6)
    }

    func testUsageAveragesFinishedRoundsOnly() {
        var log = UsageLog()
        log = log.started()
        log = log.abandoned(game: "say")
        XCTAssertNil(log.averageSeconds)
        log = log.finished(seconds: 100)
        log = log.finished(seconds: 200)
        XCTAssertEqual(log.roundsStarted, 1)
        XCTAssertEqual(log.abandoned, 1)
        XCTAssertEqual(log.averageSeconds, 150)
    }

    func testSpeechUpdatesPronunciation() {
        let stat = WordStat(id: "w").recordSpeech(.sure).recordSpeech(.close)
        XCTAssertEqual(stat.speechCount, 2)
        XCTAssertEqual(stat.pronunciation, 0.8, accuracy: 0.001)
        XCTAssertGreaterThan(stat.reviews, 0)
    }
}
