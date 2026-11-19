import XCTest
@testable import SprachduettCore

final class StreakTests: XCTestCase {
    func testPreviousDayCrossesMonthAndLeapDay() {
        XCTAssertEqual(DayKey.previous("2026-11-01"), "2026-10-31")
        XCTAssertEqual(DayKey.previous("2024-03-01"), "2024-02-29")
        XCTAssertEqual(DayKey.previous("2026-01-01"), "2025-12-31")
    }

    func testDuoStreakNeedsBothVoices() {
        let members = ["tim", "mia"]
        let stamps = [
            PracticeStamp(userID: "tim", day: "2026-11-17"),
            PracticeStamp(userID: "mia", day: "2026-11-17"),
            PracticeStamp(userID: "tim", day: "2026-11-18"),
            PracticeStamp(userID: "mia", day: "2026-11-18"),
            PracticeStamp(userID: "tim", day: "2026-11-19"),
        ]
        let status = StreakEngine.status(stamps: stamps, members: members, today: "2026-11-19")
        XCTAssertFalse(status.todayBoth)
        XCTAssertEqual(status.length, 2)
        XCTAssertEqual(status.missingToday, ["mia"])
        XCTAssertEqual(status.practicedToday, ["tim"])
    }

    func testTodayCompletesTheRun() {
        let stamps = [
            PracticeStamp(userID: "tim", day: "2026-11-18"),
            PracticeStamp(userID: "mia", day: "2026-11-18"),
            PracticeStamp(userID: "tim", day: "2026-11-19"),
            PracticeStamp(userID: "mia", day: "2026-11-19"),
        ]
        let status = StreakEngine.status(stamps: stamps, members: ["tim", "mia"], today: "2026-11-19")
        XCTAssertTrue(status.todayBoth)
        XCTAssertEqual(status.length, 2)
        XCTAssertTrue(status.missingToday.isEmpty)
    }

    func testGapBreaksTheStreak() {
        let stamps = [
            PracticeStamp(userID: "tim", day: "2026-11-17"),
            PracticeStamp(userID: "mia", day: "2026-11-17"),
            PracticeStamp(userID: "tim", day: "2026-11-19"),
            PracticeStamp(userID: "mia", day: "2026-11-19"),
        ]
        let status = StreakEngine.status(stamps: stamps, members: ["tim", "mia"], today: "2026-11-19")
        XCTAssertEqual(status.length, 1)
    }

    func testSoloCountsTheOneVoice() {
        let stamps = [
            PracticeStamp(userID: "tim", day: "2026-11-18"),
            PracticeStamp(userID: "tim", day: "2026-11-19"),
        ]
        let status = StreakEngine.status(stamps: stamps, members: ["tim"], today: "2026-11-19")
        XCTAssertTrue(status.todayBoth)
        XCTAssertEqual(status.length, 2)
    }

    func testEmptyDuoHasNoStreak() {
        let status = StreakEngine.status(stamps: [], members: [], today: "2026-11-19")
        XCTAssertEqual(status.length, 0)
        XCTAssertFalse(status.todayBoth)
    }
}
