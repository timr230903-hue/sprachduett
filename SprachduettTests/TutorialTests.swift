import XCTest
@testable import SprachduettCore

final class TutorialTests: XCTestCase {
    func testThreeShortPages() {
        XCTAssertEqual(TutorialScript.pages.map(\.id), ["handy", "spiele", "pfad"])
        XCTAssertEqual(TutorialScript.buttonTitle(index: 0), "Weiter")
        XCTAssertEqual(TutorialScript.buttonTitle(index: 2), "Los geht's")
        XCTAssertNil(TutorialScript.advance(index: 2))
        XCTAssertTrue(TutorialScript.pages[2].text.contains("null") || TutorialScript.pages[2].text.contains("Einheit"))
    }

    func testLessonCoachCoversTheThreeGames() {
        XCTAssertEqual(LessonTour.steps.map(\.id), ["intro", "listen", "say", "dialog"])
        XCTAssertEqual(LessonTour.advance(step: 0), 1)
        XCTAssertNil(LessonTour.advance(step: 3))
        XCTAssertEqual(LessonTour.buttonTitle(step: 3), "Los")
    }

    func testProgressGatesAndReplay() {
        let fresh = TutorialProgress(introSeen: false, lessonSeen: false)
        XCTAssertTrue(fresh.showsIntro)
        XCTAssertTrue(fresh.showsLessonCoach)
        let afterIntro = fresh.finishIntro()
        XCTAssertFalse(afterIntro.showsIntro)
        let done = afterIntro.finishLesson()
        XCTAssertFalse(done.showsLessonCoach)
        XCTAssertTrue(done.replay().showsLessonCoach)
    }
}
