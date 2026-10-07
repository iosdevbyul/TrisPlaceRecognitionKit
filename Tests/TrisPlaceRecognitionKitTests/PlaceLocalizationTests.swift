import XCTest
@testable import TrisPlaceRecognitionKit

final class PlaceLocalizationTests:
    XCTestCase {

    func testLocalizationResourceResolves() {
        let value =
            PlaceL10n.string(
                "place.navigation_title"
            )

        XCTAssertFalse(value.isEmpty)
        XCTAssertNotEqual(
            value,
            "place.navigation_title"
        )
    }
}
