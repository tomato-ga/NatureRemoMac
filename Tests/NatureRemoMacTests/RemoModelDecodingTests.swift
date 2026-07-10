import Foundation
import XCTest
@testable import NatureRemoMac

final class RemoModelDecodingTests: XCTestCase {
    func testDecodesSanitizedDeviceFixture() throws {
        let devices = try JSONDecoder().decode(
            [RemoDevice].self,
            from: fixtureData(named: "devices")
        )

        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].name, "Living Room Remo")
        XCTAssertEqual(devices[0].newestEvents["te"]?.value, 23.5)
    }

    func testDecodesSanitizedApplianceFixture() throws {
        let appliances = try JSONDecoder().decode(
            [RemoAppliance].self,
            from: fixtureData(named: "appliances")
        )

        XCTAssertEqual(appliances.count, 1)
        XCTAssertEqual(appliances[0].nickname, "Air Conditioner")
        XCTAssertEqual(appliances[0].signals.first?.name, "Power")
        XCTAssertEqual(appliances[0].aircon?.range?.fixedButtons, ["power-off"])
        XCTAssertEqual(appliances[0].settings?.temperature, "24")
    }
}
