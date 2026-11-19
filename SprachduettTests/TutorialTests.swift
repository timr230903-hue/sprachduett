import XCTest
@testable import SprachduettCore

final class TutorialTests: XCTestCase {
    func testIntroHasTheSixBeats() {
        let ids = TutorialScript.pages.map(\.id)
        XCTAssertEqual(ids, ["zusammen", "duo", "zeile", "toene", "serie", "zimmer"])
        XCTAssertEqual(TutorialScript.pages.filter(\.asksForSpeech).map(\.id), ["zeile"])
        XCTAssertTrue(TutorialScript.pages.contains { $0.text.contains("beide") })
        XCTAssertTrue(TutorialScript.pages.contains { $0.text.contains("Verstanden") })
        XCTAssertTrue(TutorialScript.pages.contains { $0.text.contains("Link") })
    }

    func testSpeechPermissionSitsOnTheSpeakingPage() {
        let index = TutorialScript.pages.firstIndex { $0.asksForSpeech }
        XCTAssertEqual(index, 2)
        XCTAssertEqual(TutorialScript.buttonTitle(index: 2), "Erlauben und weiter")
        XCTAssertEqual(TutorialScript.advance(index: 2), 3)
        XCTAssertEqual(TutorialScript.buttonTitle(index: 0), "Weiter")
        XCTAssertNil(TutorialScript.advance(index: 5))
        XCTAssertEqual(TutorialScript.buttonTitle(index: 5), "Los geht's")
        XCTAssertNil(TutorialScript.page(at: 9))
    }

    func testLessonCoachAdvancesThenFinishes() {
        XCTAssertEqual(LessonTour.steps.count, 3)
        XCTAssertEqual(LessonTour.advance(step: 0), 1)
        XCTAssertEqual(LessonTour.buttonTitle(step: 0), "Weiter")
        XCTAssertNil(LessonTour.advance(step: 2))
        XCTAssertEqual(LessonTour.buttonTitle(step: 2), "Los")
    }

    func testProgressGatesAndReplay() {
        let fresh = TutorialProgress(introSeen: false, lessonSeen: false)
        XCTAssertTrue(fresh.showsIntro)
        XCTAssertTrue(fresh.showsLessonCoach)
        let afterIntro = fresh.finishIntro()
        XCTAssertFalse(afterIntro.showsIntro)
        XCTAssertTrue(afterIntro.showsLessonCoach)
        let done = afterIntro.finishLesson()
        XCTAssertFalse(done.showsLessonCoach)
        let again = done.replay()
        XCTAssertFalse(again.showsIntro)
        XCTAssertTrue(again.showsLessonCoach)
    }
}
