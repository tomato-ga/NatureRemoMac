import XCTest
@testable import NatureRemoMac

final class AirconControlTests: XCTestCase {
    func testInvalidValueIsReplacedWithFirstValueAllowedBySelectedMode() {
        XCTAssertEqual(
            normalizedAirconValue("26", allowedValues: ["-1", "0", "1"]),
            "-1"
        )
    }

    func testValueAlreadyAllowedBySelectedModeIsPreserved() {
        XCTAssertEqual(
            normalizedAirconValue("auto", allowedValues: ["1", "2", "3", "auto"]),
            "auto"
        )
    }

    func testCurrentValueIsPreservedWhenAPIProvidesNoRange() {
        XCTAssertEqual(
            normalizedAirconValue("auto", allowedValues: []),
            "auto"
        )
    }
}
