import XCTest
@testable import NatureRemoMac

final class AirconControlTests: XCTestCase {
    func testControlStateSynchronizesWithRefreshedRemoteSettings() throws {
        let initialAppliance = try airconFixture(button: "power-off", temperature: "24", volume: "auto")
        let refreshedAppliance = try airconFixture(button: "", temperature: "25", volume: "1")
        var controls = AirconControlState(appliance: initialAppliance)

        XCTAssertFalse(controls.powerIsOn)

        controls.synchronize(with: refreshedAppliance)

        XCTAssertTrue(controls.powerIsOn)
        XCTAssertEqual(controls.temperature, "25")
        XCTAssertEqual(controls.operationMode, "cool")
        XCTAssertEqual(controls.airVolume, "1")
    }

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

    private func airconFixture(button: String, temperature: String, volume: String) throws -> RemoAppliance {
        let data = try fixtureData(named: "appliances")
        guard var appliances = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              var appliance = appliances.first,
              var settings = appliance["settings"] as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }

        settings["button"] = button
        settings["temp"] = temperature
        settings["vol"] = volume
        appliance["settings"] = settings
        appliances[0] = appliance

        let updatedData = try JSONSerialization.data(withJSONObject: appliances)
        return try XCTUnwrap(JSONDecoder().decode([RemoAppliance].self, from: updatedData).first)
    }
}
