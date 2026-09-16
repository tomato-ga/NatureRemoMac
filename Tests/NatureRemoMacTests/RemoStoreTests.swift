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

    func testLatestStartedRefreshWinsWhenOlderRequestFinishesLast() async throws {
        let userData = try fixtureData(named: "user")
        let deviceData = try fixtureData(named: "devices")
        let staleApplianceData = try appliancesData(temperature: "23")
        let latestApplianceData = try appliancesData(temperature: "25")
        let firstApplianceRequestStarted = expectation(description: "first appliance request started")
        let calls = RequestCallCounter()

        MockURLProtocol.installDelayed { request in
            let path = request.url?.path ?? ""
            let callNumber = calls.nextCallNumber(for: path)
            switch path {
            case "/1/users/me":
                return (response(for: request), userData, 0)
            case "/1/devices":
                return (response(for: request), deviceData, 0)
            case "/1/appliances":
                if callNumber == 1 {
                    firstApplianceRequestStarted.fulfill()
                    return (response(for: request), staleApplianceData, 0.4)
                }
                return (response(for: request), latestApplianceData, 0)
            default:
                return (response(for: request, statusCode: 404), Data(), 0)
            }
        }

        let store = makeConfiguredStore()
        let olderRefresh = Task { await store.refresh() }
        await fulfillment(of: [firstApplianceRequestStarted], timeout: 1)

        let latestRefresh = Task { await store.refresh() }
        await latestRefresh.value

        XCTAssertEqual(store.appliances.first?.settings?.temperature, "25")
        XCTAssertTrue(store.isLoading)

        await olderRefresh.value

        XCTAssertEqual(store.appliances.first?.settings?.temperature, "25")
        XCTAssertFalse(store.isLoading)
    }

    func testFullRefreshDoesNotPartiallyCommitWhenOneEndpointFails() async throws {
        let originalUserData = try fixtureData(named: "user")
        let originalDeviceData = try fixtureData(named: "devices")
        let originalApplianceData = try appliancesData(temperature: "24")
        let store = makeConfiguredStore()

        MockURLProtocol.install { request in
            switch request.url?.path {
            case "/1/users/me":
                return (response(for: request), originalUserData)
            case "/1/devices":
                return (response(for: request), originalDeviceData)
            case "/1/appliances":
                return (response(for: request), originalApplianceData)
            default:
                return (response(for: request, statusCode: 404), Data())
            }
        }
        await store.refresh()
        let originalRefreshDate = store.lastRefreshedAt

        let changedUserData = try userData(nickname: "Changed User")
        let changedDeviceData = try deviceData(name: "Changed Device")
        MockURLProtocol.install { request in
            switch request.url?.path {
            case "/1/users/me":
                return (response(for: request), changedUserData)
            case "/1/devices":
                return (response(for: request), changedDeviceData)
            case "/1/appliances":
                return (response(for: request, statusCode: 500), Data())
            default:
                return (response(for: request, statusCode: 404), Data())
            }
        }

        await store.refresh()

        XCTAssertEqual(store.user?.nickname, "Fixture User")
        XCTAssertEqual(store.devices.first?.name, "Living Room Remo")
        XCTAssertEqual(store.appliances.first?.settings?.temperature, "24")
        XCTAssertEqual(store.lastRefreshedAt, originalRefreshDate)
        XCTAssertEqual(store.notice?.kind, .failure)
    }

    func testAirconCommandsForSameApplianceRunInSubmissionOrder() async throws {
        let appliance = try XCTUnwrap(
            JSONDecoder().decode([RemoAppliance].self, from: appliancesData(temperature: "24")).first
        )
        let firstCommandStarted = expectation(description: "first aircon command started")
        let recorder = AirconCommandRecorder()

        MockURLProtocol.installDelayed { request in
            guard request.url?.path.hasSuffix("/aircon_settings") == true else {
                return (response(for: request, statusCode: 404), Data(), 0)
            }

            let temperature = formValues(from: request)["temperature"] ?? ""
            recorder.record(temperature)
            if temperature == "24" {
                firstCommandStarted.fulfill()
                return (response(for: request), Data(), 0.4)
            }
            return (response(for: request), Data(), 0)
        }

        let store = makeConfiguredStore()
        let firstCommand = Task {
            await store.setAircon(
                appliance: appliance,
                form: ["temperature": "24"],
                refreshAfterSend: false
            )
        }
        await fulfillment(of: [firstCommandStarted], timeout: 1)

        let secondCommand = Task {
            await store.setAircon(
                appliance: appliance,
                form: ["temperature": "25"],
                refreshAfterSend: false
            )
        }
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(recorder.temperatures, ["24"])

        await firstCommand.value
        await secondCommand.value

        XCTAssertEqual(recorder.temperatures, ["24", "25"])
    }

    func testAirconCommandsForDifferentAppliancesDoNotBlockEachOther() async throws {
        let firstAppliance = try XCTUnwrap(
            JSONDecoder().decode(
                [RemoAppliance].self,
                from: appliancesData(temperature: "24", applianceID: "aircon-one")
            ).first
        )
        let secondAppliance = try XCTUnwrap(
            JSONDecoder().decode(
                [RemoAppliance].self,
                from: appliancesData(temperature: "25", applianceID: "aircon-two")
            ).first
        )
        let firstCommandStarted = expectation(description: "first appliance command started")
        let secondCommandStarted = expectation(description: "second appliance command started")

        MockURLProtocol.installDelayed { request in
            let path = request.url?.path ?? ""
            if path.contains("aircon-one") {
                firstCommandStarted.fulfill()
                return (response(for: request), Data(), 0.4)
            }
            if path.contains("aircon-two") {
                secondCommandStarted.fulfill()
                return (response(for: request), Data(), 0)
            }
            return (response(for: request, statusCode: 404), Data(), 0)
        }

        let store = makeConfiguredStore()
        let firstCommand = Task {
            await store.setAircon(
                appliance: firstAppliance,
                form: ["temperature": "24"],
                refreshAfterSend: false
            )
        }
        await fulfillment(of: [firstCommandStarted], timeout: 1)

        let secondCommand = Task {
            await store.setAircon(
                appliance: secondAppliance,
                form: ["temperature": "25"],
                refreshAfterSend: false
            )
        }
        await fulfillment(of: [secondCommandStarted], timeout: 0.2)

        await firstCommand.value
        await secondCommand.value
    }

    func testSuccessfulAirconCommandInvalidatesOlderRefresh() async throws {
        let userData = try fixtureData(named: "user")
        let deviceData = try fixtureData(named: "devices")
        let initialApplianceData = try appliancesData(temperature: "24")
        let staleApplianceData = try appliancesData(temperature: "23")
        let appliance = try XCTUnwrap(
            JSONDecoder().decode([RemoAppliance].self, from: initialApplianceData).first
        )
        let store = makeConfiguredStore()

        MockURLProtocol.install { request in
            switch request.url?.path {
            case "/1/users/me":
                return (response(for: request), userData)
            case "/1/devices":
                return (response(for: request), deviceData)
            case "/1/appliances":
                return (response(for: request), initialApplianceData)
            default:
                return (response(for: request, statusCode: 404), Data())
            }
        }
        await store.refresh()

        let staleRefreshStarted = expectation(description: "stale refresh started")
        MockURLProtocol.installDelayed { request in
            switch request.url?.path {
            case "/1/users/me":
                return (response(for: request), userData, 0)
            case "/1/devices":
                return (response(for: request), deviceData, 0)
            case "/1/appliances":
                staleRefreshStarted.fulfill()
                return (response(for: request), staleApplianceData, 0.4)
            case let path? where path.hasSuffix("/aircon_settings"):
                return (response(for: request), Data(), 0)
            default:
                return (response(for: request, statusCode: 404), Data(), 0)
            }
        }

        let staleRefresh = Task { await store.refresh() }
        await fulfillment(of: [staleRefreshStarted], timeout: 1)

        await store.setAircon(
            appliance: appliance,
            form: ["temperature": "25"],
            refreshAfterSend: false
        )
        await staleRefresh.value

        XCTAssertEqual(store.appliances.first?.settings?.temperature, "24")
    }

    private func makeConfiguredStore() -> RemoStore {
        let tokenStore = InMemoryTokenStore(token: "configured-token")
        let session = MockURLProtocol.makeSession()
        return RemoStore(
            tokenStore: tokenStore,
            clientFactory: { NatureRemoClient(token: $0, session: session) }
        )
    }

    private func appliancesData(
        temperature: String,
        applianceID: String = "appliance-public-fixture"
    ) throws -> Data {
        let data = try fixtureData(named: "appliances")
        guard var appliances = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              var appliance = appliances.first,
              var settings = appliance["settings"] as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }

        settings["temp"] = temperature
        appliance["id"] = applianceID
        appliance["settings"] = settings
        appliances[0] = appliance
        return try JSONSerialization.data(withJSONObject: appliances)
    }

    private func userData(nickname: String) throws -> Data {
        let data = try fixtureData(named: "user")
        guard var user = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        user["nickname"] = nickname
        return try JSONSerialization.data(withJSONObject: user)
    }

    private func deviceData(name: String) throws -> Data {
        let data = try fixtureData(named: "devices")
        guard var devices = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              var device = devices.first else {
            throw CocoaError(.coderReadCorrupt)
        }
        device["name"] = name
        devices[0] = device
        return try JSONSerialization.data(withJSONObject: devices)
    }
}

private final class InMemoryTokenStore: TokenStoring {
    var token: String?

    init(token: String? = nil) {
        self.token = token
    }

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

private final class RequestCallCounter {
    private let lock = NSLock()
    private var callsByPath: [String: Int] = [:]

    func nextCallNumber(for path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        callsByPath[path, default: 0] += 1
        return callsByPath[path] ?? 0
    }
}

private final class AirconCommandRecorder {
    private let lock = NSLock()
    private var recordedTemperatures: [String] = []

    func record(_ temperature: String) {
        lock.lock()
        recordedTemperatures.append(temperature)
        lock.unlock()
    }

    var temperatures: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedTemperatures
    }
}

private func formValues(from request: URLRequest) -> [String: String] {
    let body = String(data: bodyData(from: request), encoding: .utf8) ?? ""
    let components = URLComponents(string: "?\(body)")
    return Dictionary(
        uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
    )
}
