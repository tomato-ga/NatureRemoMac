import Foundation

@MainActor
final class RemoStore: ObservableObject {
    struct Notice: Identifiable {
        enum Kind {
            case success
            case failure
        }

        let id: UUID = UUID()
        let kind: Kind
        let message: String
    }

    @Published private(set) var tokenIsConfigured = false
    @Published private(set) var user: RemoUser?
    @Published private(set) var devices: [RemoDevice] = []
    @Published private(set) var appliances: [RemoAppliance] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefreshedAt: Date?
    @Published var selectedApplianceID: String?
    @Published private(set) var notice: Notice?

    private let tokenStore: any TokenStoring
    private let clientFactory: (String) -> NatureRemoClient
    private var token: String?
    private var isPollingApplianceStates = false
    private var isBackgroundRefreshing = false
    private var backgroundRefreshBackoffUntil: Date?
    private var dataRequestGeneration: UInt64 = 0
    private var foregroundLoadingCount = 0
    private var activeAirconCommandIDs: Set<String> = []
    private var airconCommandWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    init(
        tokenStore: any TokenStoring = KeychainTokenStore(),
        clientFactory: @escaping (String) -> NatureRemoClient = { NatureRemoClient(token: $0) }
    ) {
        self.tokenStore = tokenStore
        self.clientFactory = clientFactory
        loadTokenFromKeychain()
    }

    var selectedAppliance: RemoAppliance? {
        guard let selectedApplianceID else {
            return appliances.first
        }
        return appliances.first { $0.id == selectedApplianceID }
    }

    var quickSignals: [QuickSignal] {
        appliances.flatMap { appliance in
            appliance.signals.prefix(4).map { QuickSignal(appliance: appliance, signal: $0) }
        }
    }

    var quickLightButtons: [QuickLightButton] {
        appliances.flatMap { appliance in
            preferredLightButtons(for: appliance)
                .prefix(2)
                .map { QuickLightButton(appliance: appliance, button: $0) }
        }
    }

    var quickTVButtons: [QuickTVButton] {
        appliances.flatMap { appliance in
            preferredTVButtons(for: appliance)
                .prefix(4)
                .map { QuickTVButton(appliance: appliance, button: $0) }
        }
    }

    func refreshIfConfigured() async {
        guard tokenIsConfigured else {
            return
        }
        await refresh()
    }

    func refresh() async {
        await refresh(scope: .full, showsNotice: true, setsLoading: true)
    }

    func refreshApplianceStatesIfConfigured() async {
        guard tokenIsConfigured else {
            return
        }

        await refresh(scope: .appliancesOnly, showsNotice: false, setsLoading: false)
    }

    func runApplianceStatePolling(intervalSeconds: UInt64 = 60) async {
        guard isPollingApplianceStates == false else {
            return
        }

        isPollingApplianceStates = true
        defer {
            isPollingApplianceStates = false
        }

        while Task.isCancelled == false {
            do {
                try await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            } catch {
                return
            }

            await refreshApplianceStatesIfConfigured()
        }
    }

    func dismissNotice(id: UUID? = nil) {
        guard id == nil || notice?.id == id else {
            return
        }
        notice = nil
    }

    private func refresh(scope: RefreshScope, showsNotice: Bool, setsLoading: Bool) async {
        guard let token, !token.isEmpty else {
            tokenIsConfigured = false
            if showsNotice {
                notice = Notice(kind: .failure, message: "Set a Nature Remo access token first.")
            }
            return
        }

        if showsNotice == false {
            guard isBackgroundRefreshAllowed else {
                return
            }
            guard isBackgroundRefreshing == false else {
                return
            }
            isBackgroundRefreshing = true
        }

        let requestGeneration = beginDataRequest()

        if setsLoading {
            beginForegroundLoading()
        }
        defer {
            if setsLoading {
                endForegroundLoading()
            }
            if showsNotice == false {
                isBackgroundRefreshing = false
            }
        }

        do {
            let client = clientFactory(token)
            switch scope {
            case .full:
                async let fetchedUser = client.fetchUser()
                async let fetchedDevices = client.fetchDevices()
                async let fetchedAppliances = client.fetchAppliances()
                let (newUser, newDevices, newAppliances) = try await (
                    fetchedUser,
                    fetchedDevices,
                    fetchedAppliances
                )

                guard requestGeneration == dataRequestGeneration else {
                    return
                }

                user = newUser
                devices = newDevices
                appliances = sortedAppliances(newAppliances)

            case .appliancesOnly:
                let newAppliances = try await client.fetchAppliances()

                guard requestGeneration == dataRequestGeneration else {
                    return
                }

                appliances = sortedAppliances(newAppliances)
            }

            if selectedApplianceID == nil || appliances.contains(where: { $0.id == selectedApplianceID }) == false {
                selectedApplianceID = appliances.first?.id
            }

            lastRefreshedAt = Date()
            backgroundRefreshBackoffUntil = nil
            if showsNotice {
                notice = Notice(kind: .success, message: "Nature Remo data refreshed.")
            }
        } catch {
            guard requestGeneration == dataRequestGeneration else {
                return
            }

            if let resetAt = rateLimitResetDate(error) {
                backgroundRefreshBackoffUntil = max(resetAt, Date().addingTimeInterval(30))
            }
            if showsNotice {
                notice = Notice(kind: .failure, message: error.localizedDescription)
            }
        }
    }

    func saveTokenAndRefresh(_ rawToken: String) async {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = Notice(kind: .failure, message: "Token is empty.")
            return
        }

        let requestGeneration = beginDataRequest()
        beginForegroundLoading()
        defer {
            endForegroundLoading()
        }

        do {
            let client = clientFactory(trimmed)
            let validatedUser = try await client.fetchUser()
            async let fetchedDevices = client.fetchDevices()
            async let fetchedAppliances = client.fetchAppliances()
            let (validatedDevices, newAppliances) = try await (
                fetchedDevices,
                fetchedAppliances
            )

            guard requestGeneration == dataRequestGeneration else {
                return
            }

            let validatedAppliances = sortedAppliances(newAppliances)

            try tokenStore.saveToken(trimmed)
            token = trimmed
            tokenIsConfigured = true
            user = validatedUser
            devices = validatedDevices
            appliances = validatedAppliances
            if selectedApplianceID == nil || appliances.contains(where: { $0.id == selectedApplianceID }) == false {
                selectedApplianceID = appliances.first?.id
            }
            lastRefreshedAt = Date()
            backgroundRefreshBackoffUntil = nil
            notice = Notice(kind: .success, message: "Token validated and Nature Remo data refreshed.")
        } catch {
            guard requestGeneration == dataRequestGeneration else {
                return
            }
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func clearToken() {
        do {
            try tokenStore.deleteToken()
            invalidateDataRequests()
            token = nil
            tokenIsConfigured = false
            user = nil
            devices = []
            appliances = []
            selectedApplianceID = nil
            notice = Notice(kind: .success, message: "Token removed.")
        } catch {
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func send(signal: RemoSignal, applianceName: String) async {
        guard let client = makeClient() else {
            return
        }

        do {
            try await client.sendSignal(id: signal.id)
            notice = Notice(kind: .success, message: "Sent \(signal.name) to \(applianceName).")
            await refreshApplianceStatesIfConfigured()
        } catch {
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func setAircon(appliance: RemoAppliance, form: [String: String], refreshAfterSend: Bool = true) async {
        await acquireAirconCommandSlot(applianceID: appliance.id)
        defer {
            releaseAirconCommandSlot(applianceID: appliance.id)
        }

        guard let client = makeClient() else {
            return
        }

        do {
            try await client.setAircon(applianceID: appliance.id, form: form)
            invalidateDataRequests()
            notice = Notice(kind: .success, message: "Sent air conditioner settings to \(appliance.nickname).")
            if refreshAfterSend && hasWaitingAirconCommand(applianceID: appliance.id) == false {
                await refreshApplianceStatesIfConfigured()
            }
        } catch {
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func sendLightButton(_ button: RemoLightButton, appliance: RemoAppliance) async {
        guard let client = makeClient() else {
            return
        }

        do {
            try await client.sendLightButton(applianceID: appliance.id, buttonName: button.name)
            notice = Notice(kind: .success, message: "Sent \(button.displayName) to \(appliance.nickname).")
            await refreshApplianceStatesIfConfigured()
        } catch {
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func sendTVButton(_ button: RemoLightButton, appliance: RemoAppliance) async {
        guard let client = makeClient() else {
            return
        }

        do {
            try await client.sendTVButton(applianceID: appliance.id, buttonName: button.name)
            notice = Notice(kind: .success, message: "\(appliance.nickname) に \(localizedTVButtonName(button)) を送信しました。")
            await refreshApplianceStatesIfConfigured()
        } catch {
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func preferredLightButtons(for appliance: RemoAppliance) -> [RemoLightButton] {
        guard let buttons = appliance.light?.buttons, buttons.isEmpty == false else {
            return []
        }

        let preferredNames = ["on", "off", "power-on", "power-off"]
        let preferred = buttons.filter { preferredNames.contains($0.normalizedName) }
        let remaining = buttons.filter { preferredNames.contains($0.normalizedName) == false }
        return preferred + remaining
    }

    func preferredTVButtons(for appliance: RemoAppliance) -> [RemoLightButton] {
        guard let buttons = appliance.tv?.buttons, buttons.isEmpty == false else {
            return []
        }

        let preferredNames = ["power", "input", "mute", "vol-up", "vol-down", "ch-up", "ch-down"]
        let preferred = buttons.filter { preferredNames.contains($0.normalizedName) }
        let remaining = buttons.filter { preferredNames.contains($0.normalizedName) == false }
        return preferred + remaining
    }

    private func loadTokenFromKeychain() {
        do {
            let savedToken = try tokenStore.readToken()
            token = savedToken
            tokenIsConfigured = savedToken?.isEmpty == false
        } catch {
            token = nil
            tokenIsConfigured = false
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    private func makeClient() -> NatureRemoClient? {
        guard let token, !token.isEmpty else {
            notice = Notice(kind: .failure, message: NatureRemoAPIError.missingToken.localizedDescription)
            return nil
        }

        return clientFactory(token)
    }

    private func beginDataRequest() -> UInt64 {
        dataRequestGeneration &+= 1
        return dataRequestGeneration
    }

    private func invalidateDataRequests() {
        dataRequestGeneration &+= 1
    }

    private func beginForegroundLoading() {
        foregroundLoadingCount += 1
        isLoading = true
    }

    private func endForegroundLoading() {
        foregroundLoadingCount = max(0, foregroundLoadingCount - 1)
        isLoading = foregroundLoadingCount > 0
    }

    private func sortedAppliances(_ appliances: [RemoAppliance]) -> [RemoAppliance] {
        appliances.sorted {
            $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
        }
    }

    private func acquireAirconCommandSlot(applianceID: String) async {
        if activeAirconCommandIDs.insert(applianceID).inserted {
            return
        }

        await withCheckedContinuation { continuation in
            airconCommandWaiters[applianceID, default: []].append(continuation)
        }
    }

    private func releaseAirconCommandSlot(applianceID: String) {
        guard var waiters = airconCommandWaiters[applianceID], waiters.isEmpty == false else {
            airconCommandWaiters[applianceID] = nil
            activeAirconCommandIDs.remove(applianceID)
            return
        }

        let next = waiters.removeFirst()
        airconCommandWaiters[applianceID] = waiters.isEmpty ? nil : waiters
        next.resume()
    }

    private func hasWaitingAirconCommand(applianceID: String) -> Bool {
        airconCommandWaiters[applianceID]?.isEmpty == false
    }

    private var isBackgroundRefreshAllowed: Bool {
        guard isLoading == false else {
            return false
        }
        guard let backgroundRefreshBackoffUntil else {
            return true
        }
        return Date() >= backgroundRefreshBackoffUntil
    }

    private func rateLimitResetDate(_ error: Error) -> Date? {
        if case NatureRemoAPIError.rateLimited(let resetAt) = error {
            return resetAt ?? Date().addingTimeInterval(300)
        }
        return nil
    }
}

private enum RefreshScope {
    case full
    case appliancesOnly
}
