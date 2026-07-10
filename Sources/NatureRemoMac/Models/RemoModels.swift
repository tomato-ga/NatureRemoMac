import Foundation

struct RemoUser: Decodable {
    let id: String
    let nickname: String
}

struct RemoDevice: Decodable, Identifiable {
    let id: String
    let name: String
    let firmwareVersion: String?
    let newestEvents: [String: RemoEvent]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case firmwareVersion = "firmware_version"
        case newestEvents = "newest_events"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? container.decode(String.self, forKey: .name)) ?? "Remo"
        firmwareVersion = try? container.decode(String.self, forKey: .firmwareVersion)
        newestEvents = (try? container.decode([String: RemoEvent].self, forKey: .newestEvents)) ?? [:]
    }
}

struct RemoDeviceSummary: Decodable {
    let id: String?
    let name: String?
}

struct RemoEvent: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let value: Double?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case value = "val"
        case createdAt = "created_at"
    }
}

struct RemoAppliance: Decodable, Identifiable {
    let id: String
    let type: String
    let nickname: String
    let image: String?
    let device: RemoDeviceSummary?
    let signals: [RemoSignal]
    let aircon: RemoAircon?
    let light: RemoLight?
    let tv: RemoTV?
    let matterBridgedDeviceState: String?
    let settings: RemoAirconSettings?

    var displayType: String {
        if aircon != nil {
            return "Air conditioner"
        }
        if light != nil || type.uppercased() == "LIGHT" {
            return "Light"
        }
        if tv != nil || type.uppercased() == "TV" {
            return "TV"
        }
        return type.isEmpty ? "Appliance" : type
    }

    var isLight: Bool {
        light != nil || type.uppercased() == "LIGHT"
    }

    var isTV: Bool {
        tv != nil || type.uppercased() == "TV"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case nickname
        case image
        case device
        case signals
        case aircon
        case light
        case tv
        case matterBridgedDeviceState = "matter_bridged_device_state"
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        nickname = (try? container.decode(String.self, forKey: .nickname)) ?? "Appliance"
        image = try? container.decode(String.self, forKey: .image)
        device = try? container.decode(RemoDeviceSummary.self, forKey: .device)
        signals = (try? container.decode([RemoSignal].self, forKey: .signals)) ?? []
        aircon = try? container.decode(RemoAircon.self, forKey: .aircon)
        light = try? container.decode(RemoLight.self, forKey: .light)
        tv = try? container.decode(RemoTV.self, forKey: .tv)
        matterBridgedDeviceState = try? container.decode(String.self, forKey: .matterBridgedDeviceState)
        settings = try? container.decode(RemoAirconSettings.self, forKey: .settings)
    }
}

struct RemoSignal: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let image: String?
}

struct RemoAircon: Decodable {
    let range: RemoAirconRange?
    let tempUnit: String?

    private enum CodingKeys: String, CodingKey {
        case range
        case tempUnit
    }
}

struct RemoAirconRange: Decodable {
    let modes: [String: RemoAirconModeRange]
    let fixedButtons: [String]

    private enum CodingKeys: String, CodingKey {
        case modes
        case fixedButtons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modes = (try? container.decode([String: RemoAirconModeRange].self, forKey: .modes)) ?? [:]
        fixedButtons = (try? container.decode([String].self, forKey: .fixedButtons)) ?? []
    }
}

struct RemoAirconModeRange: Decodable {
    let temp: [String]
    let vol: [String]
    let dir: [String]
    let dirh: [String]

    private enum CodingKeys: String, CodingKey {
        case temp
        case vol
        case dir
        case dirh
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        temp = (try? container.decode([String].self, forKey: .temp)) ?? []
        vol = (try? container.decode([String].self, forKey: .vol)) ?? []
        dir = (try? container.decode([String].self, forKey: .dir)) ?? []
        dirh = (try? container.decode([String].self, forKey: .dirh)) ?? []
    }
}

struct RemoAirconSettings: Decodable {
    let temperature: String?
    let temperatureUnit: String?
    let mode: String?
    let volume: String?
    let direction: String?
    let horizontalDirection: String?
    let button: String?
    let updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case temperature = "temp"
        case temperatureUnit = "temp_unit"
        case mode
        case volume = "vol"
        case direction = "dir"
        case horizontalDirection = "dirh"
        case button
        case updatedAt = "updated_at"
    }
}

struct RemoLight: Decodable {
    let buttons: [RemoLightButton]
    let state: RemoLightState?

    private enum CodingKeys: String, CodingKey {
        case buttons
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttons = (try? container.decode([RemoLightButton].self, forKey: .buttons)) ?? []
        state = try? container.decode(RemoLightState.self, forKey: .state)
    }
}

struct RemoLightButton: Decodable, Identifiable, Hashable {
    let name: String
    let image: String?
    let label: String

    var id: String { name }

    var displayName: String {
        label.isEmpty ? name : label
    }

    var normalizedName: String {
        name.lowercased()
    }
}

struct RemoLightState: Decodable {
    let brightness: String?
    let lastButton: String?
    let power: String?

    private enum CodingKeys: String, CodingKey {
        case brightness
        case lastButton = "last_button"
        case power
    }
}

struct RemoTV: Decodable {
    let buttons: [RemoLightButton]
    let layout: [RemoTVRowLayout]
    let state: RemoTVState?

    private enum CodingKeys: String, CodingKey {
        case buttons
        case layout
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttons = (try? container.decode([RemoLightButton].self, forKey: .buttons)) ?? []
        layout = (try? container.decode([RemoTVRowLayout].self, forKey: .layout)) ?? []
        state = try? container.decode(RemoTVState.self, forKey: .state)
    }
}

struct RemoTVRowLayout: Decodable, Identifiable, Hashable {
    let type: String
    let buttons: [String]

    var id: String {
        "\(type)-\(buttons.joined(separator: "-"))"
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case buttons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type)) ?? "row"
        buttons = (try? container.decode([String].self, forKey: .buttons)) ?? []
    }
}

struct RemoTVState: Decodable {
    let input: String?
}

struct QuickSignal: Identifiable {
    let appliance: RemoAppliance
    let signal: RemoSignal

    var id: String {
        "\(appliance.id)-\(signal.id)"
    }
}

struct QuickLightButton: Identifiable {
    let appliance: RemoAppliance
    let button: RemoLightButton

    var id: String {
        "\(appliance.id)-light-\(button.name)"
    }
}

struct QuickTVButton: Identifiable {
    let appliance: RemoAppliance
    let button: RemoLightButton

    var id: String {
        "\(appliance.id)-tv-\(button.name)"
    }
}
