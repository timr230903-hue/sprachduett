import XCTest
@testable import SprachduettCore

final class CatalogTests: XCTestCase {
    func testBundledCatalog() throws {
        let catalog = try CatalogLoader.loadBundled()
        XCTAssertEqual(catalog.language, "th")
        XCTAssertGreaterThanOrEqual(catalog.phraseCount, 300)
        XCTAssertGreaterThanOrEqual(catalog.scenes.count, 12)
        XCTAssertEqual(catalog.tones.map(\.id), ["mid", "low", "falling", "high", "rising"])
        XCTAssertEqual(catalog.tones.map(\.exampleThai), ["ไป", "ใหม่", "ไม่", "ไม้", "ไหม"])
        XCTAssertEqual(catalog.tones.map(\.exampleRoman), ["bpai", "mài", "mâi", "mái", "mǎi"])
        let ids: Set<String> = [
            "begruessung", "kennenlernen", "restaurant", "markt", "taxi", "weg",
            "cafe", "hotel", "streetfood", "souvenir", "apotheke", "verabredung",
            "bahn", "ausflug",
        ]
        XCTAssertFalse(catalog.phrases.contains { $0.thai.contains("อรุณสวัสดิ์") || $0.thai.contains("ราตรีสวัสดิ์") || $0.thai == "ดิฉัน" })
        XCTAssertEqual(catalog.phrases.first { $0.id == "food-01" }?.roman, "khâao")
        XCTAssertEqual(catalog.phrases.first { $0.id == "pol-01" }?.roman, "sà-wàt-dii")
        XCTAssertEqual(catalog.phrases.first { $0.id == "dri-01" }?.roman, "náam")
        XCTAssertEqual(catalog.phrases.first { $0.id == "ton-09" }?.roman, "khâao")
        XCTAssertEqual(catalog.phrases.first { $0.id == "ton-12" }?.roman, "khàao")
        XCTAssertTrue(ids.isSubset(of: Set(catalog.scenes.map(\.id))))
        for scene in catalog.scenes {
            XCTAssertGreaterThanOrEqual(scene.lines.count, 6)
            XCTAssertEqual(Set(scene.lines.map(\.role)), [.a, .b])
        }
    }

    func testRejectsShortCatalog() throws {
        let raw = """
        {"language":"th","title":"Thai","tones":[],"topics":[],"scenes":[]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try CatalogLoader.decode(raw))
    }

    func testBrokenJSON() {
        XCTAssertThrowsError(try CatalogLoader.decode(Data("[]".utf8)))
    }
}
