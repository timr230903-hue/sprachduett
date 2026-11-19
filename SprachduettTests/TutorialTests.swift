import XCTest
@testable import SprachduettCore

final class TutorialTests: XCTestCase {
    func testOneScreenOnboarding() {
        XCTAssertEqual(TutorialScript.pages.count, 1)
        XCTAssertEqual(TutorialScript.pages[0].text, "Ihr spielt zu zweit auf einem Handy. Hört zu, sprecht laut, tippt.")
        XCTAssertNil(TutorialScript.advance(index: 0))
        XCTAssertEqual(TutorialScript.buttonTitle(index: 0), "Los geht's")
    }

    func testLessonCoachCoversTheThreeGames() {
        XCTAssertEqual(LessonTour.steps.map(\.id), ["intro", "listen", "say", "dialog"])
        XCTAssertNil(LessonTour.advance(step: 3))
    }

    func testProgressGatesAndReplay() {
        let fresh = TutorialProgress(introSeen: false, lessonSeen: false)
        XCTAssertTrue(fresh.showsIntro)
        let done = fresh.finishIntro().finishLesson()
        XCTAssertFalse(done.showsLessonCoach)
        XCTAssertTrue(done.replay().showsLessonCoach)
    }
}
