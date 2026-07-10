import Foundation
import XCTest
@testable import NatureRemoMac

@MainActor
final class RemoStoreTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRejectedTokenIsNotPersisted() async {
        MockURLProtocol.install { request in
            (response(for: request, statusCode: 401), Data())
        }
        let tokenStore = InMemoryTokenStore()
        let session = MockURLProtocol.makeSession()
        let store = RemoStore(
            tokenStore: tokenStore,
            clientFactory: { NatureRemoClient(token: $0, session: session) }
        )

        await store.saveTokenAndRefresh("rejected-token")

        XCTAssertNil(tokenStore.token)
        XCTAssertFalse(store.tokenIsConfigured)
        XCTAssertTrue(store.notice?.message.contains("rejected") == true)
    }

    func testValidatedTokenLoadsDataAndIsPersisted() async throws {
        let userData = try fixtureData(named: "user")
        let deviceData = try fixtureData(named: "devices")
        let applianceData = try fixtureData(named: "appliances")
        MockURLProtocol.install { request in
            switch request.url?.path {
            case "/1/users/me":
                return (response(for: request), userData)
            case "/1/devices":
                return (response(for: request), deviceData)
            case "/1/appliances":
                return (response(for: request), applianceData)
            default:
                return (response(for: request, statusCode: 404), Data())
            }
        }
        let tokenStore = InMemoryTokenStore()
        let session = MockURLProtocol.makeSession()
        let store = RemoStore(
            tokenStore: tokenStore,
            clientFactory: { NatureRemoClient(token: $0, session: session) }
        )

        await store.saveTokenAndRefresh("validated-token")

        XCTAssertEqual(tokenStore.token, "validated-token")
        XCTAssertTrue(store.tokenIsConfigured)
        XCTAssertEqual(store.user?.nickname, "Fixture User")
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.appliances.count, 1)
        XCTAssertEqual(store.selectedApplianceID, "appliance-public-fixture")
    }
}

private final class InMemoryTokenStore: TokenStoring {
    var token: String?

    func readToken() throws -> String? {
        token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}
