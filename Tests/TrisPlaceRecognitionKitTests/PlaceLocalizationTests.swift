import Foundation
import XCTest
@testable import TrisPlaceRecognitionKit

final class PlaceLocalizationTests:
    XCTestCase {

    func testEnglishLocalizationUsesEnglishText() throws {
        let bundle = try localizedBundle(language: "en")

        XCTAssertEqual(
            bundle.localizedString(
                forKey: "place.navigation_title",
                value: nil,
                table: nil
            ),
            "Places"
        )

        XCTAssertEqual(
            bundle.localizedString(
                forKey: "place.notification.arrival_title",
                value: nil,
                table: nil
            ),
            "Place Arrival"
        )
    }

    func testKoreanLocalizationUsesKoreanText() throws {
        let bundle = try localizedBundle(language: "ko")

        XCTAssertEqual(
            bundle.localizedString(
                forKey: "place.navigation_title",
                value: nil,
                table: nil
            ),
            "장소"
        )

        XCTAssertEqual(
            bundle.localizedString(
                forKey: "place.notification.arrival_title",
                value: nil,
                table: nil
            ),
            "장소 도착"
        )
    }

    private func localizedBundle(
        language: String
    ) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.module.path(
                forResource: language,
                ofType: "lproj"
            )
        )

        return try XCTUnwrap(Bundle(path: path))
    }
}
