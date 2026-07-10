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

        if setsLoading {
            isLoading = true
        }
        defer {
            if setsLoading {
                isLoading = false
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

                user = try await fetchedUser
                devices = try await fetchedDevices
                appliances = try await fetchedAppliances.sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }

            case .appliancesOnly:
                appliances = try await client.fetchAppliances().sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
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

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let client = clientFactory(trimmed)
            let validatedUser = try await client.fetchUser()
            async let fetchedDevices = client.fetchDevices()
            async let fetchedAppliances = client.fetchAppliances()
            let validatedDevices = try await fetchedDevices
            let validatedAppliances = try await fetchedAppliances.sorted {
                $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
            }

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
            notice = Notice(kind: .failure, message: error.localizedDescription)
        }
    }

    func clearToken() {
        do {
            try tokenStore.deleteToken()
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
        guard let client = makeClient() else {
            return
        }

        do {
            try await client.setAircon(applianceID: appliance.id, form: form)
            notice = Notice(kind: .success, message: "Sent air conditioner settings to \(appliance.nickname).")
            if refreshAfterSend {
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
