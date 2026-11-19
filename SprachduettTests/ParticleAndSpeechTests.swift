import XCTest
@testable import SprachduettCore

final class ParticleAndSpeechTests: XCTestCase {
    func testParticlesFollowGender() {
        let male = Particles.apply(thai: "สวัสดี", roman: "sà-wàt-dii", particle: .statement, gender: .male)
        XCTAssertEqual(male.thai, "สวัสดีครับ")
        XCTAssertEqual(male.roman, "sà-wàt-dii khráp")

        let femaleSaid = Particles.apply(thai: "สวัสดี", roman: "sà-wàt-dii", particle: .statement, gender: .female)
        XCTAssertEqual(femaleSaid.thai, "สวัสดีค่ะ")
        XCTAssertEqual(femaleSaid.roman, "sà-wàt-dii khâ")

        let femaleAsked = Particles.apply(thai: "อร่อยไหม", roman: "à-rɔ̀i mǎi", particle: .question, gender: .female)
        XCTAssertEqual(femaleAsked.thai, "อร่อยไหมคะ")
        XCTAssertEqual(femaleAsked.roman, "à-rɔ̀i mǎi khá")

        let maleAsked = Particles.apply(thai: "อร่อยไหม", roman: "à-rɔ̀i mǎi", particle: .question, gender: .male)
        XCTAssertEqual(maleAsked.thai, "อร่อยไหมครับ")

        let plain = Particles.apply(thai: "น้ำ", roman: "náam", particle: .none, gender: .female)
        XCTAssertEqual(plain.thai, "น้ำ")
        XCTAssertEqual(plain.roman, "náam")

        let open = Particles.apply(thai: "สวัสดี", roman: "sà-wàt-dii", particle: .statement, gender: .unspecified)
        XCTAssertEqual(open.thai, "สวัสดี")
    }

    func testParticleIsNotDoubled() {
        let spoken = Particles.apply(thai: "สวัสดีครับ", roman: "sà-wàt-dii khráp", particle: .statement, gender: .male)
        XCTAssertEqual(spoken.thai, "สวัสดีครับ")
        XCTAssertEqual(spoken.roman, "sà-wàt-dii khráp")
    }

    func testGenderSwitchesPronounAndParticle() {
        let male = GenderVoice.speak(thai: "ผมสบายดี", roman: "phǒm sà-baai-dii", gender: .male, polite: true)
        XCTAssertEqual(male.thai, "ผมสบายดีครับ")
        XCTAssertEqual(male.roman, "phǒm sà-baai-dii khráp")

        let female = GenderVoice.speak(thai: "ผมสบายดี", roman: "phǒm sà-baai-dii", gender: .female, polite: true)
        XCTAssertEqual(female.thai, "ฉันสบายดีค่ะ")
        XCTAssertEqual(female.roman, "chǎn sà-baai-dii khâ")

        let asked = GenderVoice.speak(thai: "สบายดีไหม", roman: "sà-baai-dii mǎi", gender: .female, polite: true)
        XCTAssertEqual(asked.thai, "สบายดีไหมคะ")

        let noun = GenderVoice.speak(thai: "น้ำ", roman: "náam", gender: .male, polite: false)
        XCTAssertEqual(noun.thai, "น้ำ")
    }

    func testRomanizationFadesAsTheWordSticks() {
        XCTAssertEqual(RomanFade.opacity(stage: 1, mastered: true, reviews: 9, pronunciation: 1, hidden: false), 1, accuracy: 0.001)
        XCTAssertEqual(RomanFade.opacity(stage: 2, mastered: true, reviews: 4, pronunciation: 0.5, hidden: false), 0, accuracy: 0.001)
        XCTAssertEqual(RomanFade.opacity(stage: 2, mastered: false, reviews: 0, pronunciation: 0, hidden: false), 1, accuracy: 0.001)
        XCTAssertGreaterThan(
            RomanFade.opacity(stage: 2, mastered: false, reviews: 1, pronunciation: 0.2, hidden: false),
            RomanFade.opacity(stage: 2, mastered: false, reviews: 5, pronunciation: 0.8, hidden: false)
        )
        XCTAssertEqual(RomanFade.opacity(stage: 1, mastered: false, reviews: 0, pronunciation: 0, hidden: true), 0, accuracy: 0.001)
    }

    func testSpeechAcceptsParticleAndNearMiss() {
        XCTAssertTrue(SpeechMatch.accepts(recognized: "สวัสดีครับ", expectedThai: "สวัสดี"))
        XCTAssertTrue(SpeechMatch.accepts(recognized: "สวัสดี ค่ะ", expectedThai: "สวัสดีครับ"))
        XCTAssertTrue(SpeechMatch.accepts(recognized: "สวัสดีคับ", expectedThai: "สวัสดีครับ"))
        XCTAssertFalse(SpeechMatch.accepts(recognized: "ขอบคุณ", expectedThai: "สวัสดี"))
        XCTAssertFalse(SpeechMatch.accepts(recognized: "", expectedThai: "น้ำ"))
        XCTAssertFalse(SpeechMatch.accepts(recognized: "น้ำ", expectedThai: ""))
    }
}
