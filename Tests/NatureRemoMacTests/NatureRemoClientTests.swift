import Foundation
import XCTest
@testable import NatureRemoMac

final class NatureRemoClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchUserSendsBearerTokenToExpectedEndpoint() async throws {
        let expectedData = try fixtureData(named: "user")
        MockURLProtocol.install { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.nature.global/1/users/me")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "NatureRemoMac/0.1.0")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
            return (response(for: request), expectedData)
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())
        let user = try await client.fetchUser()

        XCTAssertEqual(user.id, "user-public-fixture")
        XCTAssertEqual(user.nickname, "Fixture User")
    }

    func testAirconRequestUsesFormEncoding() async throws {
        MockURLProtocol.install { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://api.nature.global/1/appliances/appliance-id/aircon_settings"
            )
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Content-Type"),
                "application/x-www-form-urlencoded"
            )

            let body = String(data: bodyData(from: request), encoding: .utf8)
            let components = URLComponents(string: "?\(body ?? "")")
            let values = Dictionary(
                uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
            )
            XCTAssertEqual(values["temperature"], "24")
            XCTAssertEqual(values["operation_mode"], "cool")
            XCTAssertEqual(values["button"], "")
            return (response(for: request), Data())
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())
        try await client.setAircon(
            applianceID: "appliance-id",
            form: [
                "temperature": "24",
                "operation_mode": "cool",
                "button": ""
            ]
        )
    }

    func testCollectionEndpointsUseExpectedPaths() async throws {
        let deviceData = try fixtureData(named: "devices")
        let applianceData = try fixtureData(named: "appliances")
        MockURLProtocol.install { request in
            switch request.url?.path {
            case "/1/devices":
                return (response(for: request), deviceData)
            case "/1/appliances":
                return (response(for: request), applianceData)
            default:
                return (response(for: request, statusCode: 404), Data())
            }
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())
        let devices = try await client.fetchDevices()
        let appliances = try await client.fetchAppliances()

        XCTAssertEqual(devices.first?.id, "device-public-fixture")
        XCTAssertEqual(appliances.first?.id, "appliance-public-fixture")
    }

    func testControlEndpointsUseExpectedPathsAndButtons() async throws {
        var requests: [(path: String, values: [String: String])] = []
        MockURLProtocol.install { request in
            let body = String(data: bodyData(from: request), encoding: .utf8) ?? ""
            let components = URLComponents(string: "?\(body)")
            let values = Dictionary(
                uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
            )
            requests.append((request.url?.path ?? "", values))
            XCTAssertEqual(request.httpMethod, "POST")
            return (response(for: request), Data())
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())
        try await client.sendSignal(id: "signal-id")
        try await client.sendLightButton(applianceID: "light-id", buttonName: "on")
        try await client.sendTVButton(applianceID: "tv-id", buttonName: "power")

        XCTAssertEqual(requests.map(\.path), [
            "/1/signals/signal-id/send",
            "/1/appliances/light-id/light",
            "/1/appliances/tv-id/tv"
        ])
        XCTAssertEqual(requests[1].values["button"], "on")
        XCTAssertEqual(requests[2].values["button"], "power")
    }

    func testUnauthorizedResponseDoesNotExposeResponseBody() async {
        MockURLProtocol.install { request in
            (
                response(for: request, statusCode: 401),
                Data("raw-sensitive-provider-response".utf8)
            )
        }

        let client = NatureRemoClient(token: "rejected", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.fetchUser()
            XCTFail("Expected an unauthorized error")
        } catch let error as NatureRemoAPIError {
            guard case .unauthorized = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("raw-sensitive"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRateLimitResponseIncludesResetDate() async {
        let resetEpoch = Date().addingTimeInterval(120).timeIntervalSince1970
        MockURLProtocol.install { request in
            (
                response(
                    for: request,
                    statusCode: 429,
                    headers: ["X-Rate-Limit-Reset": String(resetEpoch)]
                ),
                Data()
            )
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.fetchDevices()
            XCTFail("Expected a rate-limit error")
        } catch let error as NatureRemoAPIError {
            guard case .rateLimited(let resetAt) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(resetAt?.timeIntervalSince1970 ?? 0, resetEpoch, accuracy: 0.001)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnknownServerResponseDoesNotExposeRawBody() async {
        MockURLProtocol.install { request in
            (
                response(for: request, statusCode: 500),
                Data("upstream-debug-output-with-private-data".utf8)
            )
        }

        let client = NatureRemoClient(token: "test-token", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.fetchUser()
            XCTFail("Expected an HTTP error")
        } catch let error as NatureRemoAPIError {
            XCTAssertEqual(error.localizedDescription, "Nature Remo API returned HTTP 500.")
            XCTAssertFalse(error.localizedDescription.contains("private-data"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
