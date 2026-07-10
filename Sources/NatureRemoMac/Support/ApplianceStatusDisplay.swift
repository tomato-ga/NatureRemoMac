import Foundation
import SwiftUI

enum StatusTone {
    case active
    case inactive
    case cooling
    case heating
    case drying
    case fan
    case warning
    case neutral

    var color: Color {
        switch self {
        case .active:
            return .green
        case .inactive:
            return .secondary
        case .cooling:
            return .cyan
        case .heating:
            return .orange
        case .drying:
            return .teal
        case .fan:
            return .blue
        case .warning:
            return .yellow
        case .neutral:
            return .accentColor
        }
    }

    var systemImage: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .inactive:
            return "power.circle"
        case .cooling:
            return "snowflake"
        case .heating:
            return "flame.fill"
        case .drying:
            return "drop.fill"
        case .fan:
            return "fanblades.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "circle.fill"
        }
    }
}

struct ApplianceStatusSnapshot {
    let title: String
    let subtitle: String
    let tone: StatusTone
    let rows: [StatusRow]
    let isAvailable: Bool
    let updatedAt: String?

    struct StatusRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let tone: StatusTone

        init(label: String, value: String, tone: StatusTone = .neutral) {
            self.label = label
            self.value = value
            self.tone = tone
        }
    }
}

func applianceStatusSnapshot(for appliance: RemoAppliance) -> ApplianceStatusSnapshot {
    if let settings = appliance.settings {
        return airconStatusSnapshot(settings)
    }

    if let state = appliance.light?.state {
        return lightStatusSnapshot(state)
    }

    if let state = appliance.tv?.state {
        return tvStatusSnapshot(state)
    }

    if let state = appliance.matterBridgedDeviceState, state.isEmpty == false {
        return ApplianceStatusSnapshot(
            title: localizedMatterState(state),
            subtitle: "Matter状態",
            tone: statusTone(forPower: state),
            rows: [ApplianceStatusSnapshot.StatusRow(label: "状態", value: localizedMatterState(state), tone: statusTone(forPower: state))],
            isAvailable: true,
            updatedAt: nil
        )
    }

    return ApplianceStatusSnapshot(
        title: "状態未取得",
        subtitle: "この家電はAPIから状態が返っていません",
        tone: .warning,
        rows: [
            ApplianceStatusSnapshot.StatusRow(label: "取得元", value: "未対応または学習リモコン", tone: .warning)
        ],
        isAvailable: false,
        updatedAt: nil
    )
}

func compactApplianceStatus(for appliance: RemoAppliance) -> String {
    applianceStatusSnapshot(for: appliance).title
}

func localizedAirconMode(_ mode: String?) -> String {
    guard let mode, mode.isEmpty == false else {
        return "-"
    }

    switch mode.lowercased() {
    case "auto":
        return "自動"
    case "cool":
        return "冷房"
    case "warm", "heat":
        return "暖房"
    case "dry":
        return "除湿"
    case "blow", "fan":
        return "送風"
    default:
        return mode
    }
}

func localizedAirVolume(_ value: String?) -> String {
    guard let value else {
        return "-"
    }
    return value.isEmpty || value.lowercased() == "auto" ? "自動" : "風量 \(value)"
}

func localizedAirDirection(_ value: String?) -> String {
    guard let value else {
        return "-"
    }
    return value.isEmpty || value.lowercased() == "auto" ? "自動" : value
}

func localizedPowerState(_ value: String?) -> String {
    guard let value, value.isEmpty == false else {
        return "-"
    }

    switch value.lowercased() {
    case "on":
        return "オン"
    case "off":
        return "オフ"
    default:
        return value
    }
}

func localizedLightButton(_ value: String?) -> String {
    guard let value, value.isEmpty == false else {
        return "-"
    }

    switch value.lowercased() {
    case "on", "power-on":
        return "オン"
    case "off", "power-off":
        return "オフ"
    case "bright-up":
        return "明るく"
    case "bright-down":
        return "暗く"
    default:
        return value
    }
}

private func airconStatusSnapshot(_ settings: RemoAirconSettings) -> ApplianceStatusSnapshot {
    let isOff = settings.button?.lowercased() == "power-off"
    let tone = isOff ? StatusTone.inactive : airconTone(for: settings.mode)
    let mode = localizedAirconMode(settings.mode)
    let temperature = settings.temperature.map { "\($0)℃" } ?? "-"
    let title = isOff ? "オフ" : "\(mode) \(temperature)"

    var rows = [
        ApplianceStatusSnapshot.StatusRow(label: "電源", value: isOff ? "オフ" : "オン", tone: isOff ? .inactive : .active),
        ApplianceStatusSnapshot.StatusRow(label: "運転モード", value: mode, tone: tone),
        ApplianceStatusSnapshot.StatusRow(label: "温度", value: temperature),
        ApplianceStatusSnapshot.StatusRow(label: "風量", value: localizedAirVolume(settings.volume)),
        ApplianceStatusSnapshot.StatusRow(label: "上下風向", value: localizedAirDirection(settings.direction)),
        ApplianceStatusSnapshot.StatusRow(label: "左右風向", value: localizedAirDirection(settings.horizontalDirection))
    ]

    if let updatedAt = formattedStatusDate(settings.updatedAt) {
        rows.append(ApplianceStatusSnapshot.StatusRow(label: "更新", value: updatedAt))
    }

    return ApplianceStatusSnapshot(
        title: title,
        subtitle: "Nature Remoが保持しているエアコン設定",
        tone: tone,
        rows: rows,
        isAvailable: true,
        updatedAt: formattedStatusDate(settings.updatedAt)
    )
}

private func lightStatusSnapshot(_ state: RemoLightState) -> ApplianceStatusSnapshot {
    let tone = statusTone(forPower: state.power)
    var rows = [
        ApplianceStatusSnapshot.StatusRow(label: "電源", value: localizedPowerState(state.power), tone: tone),
        ApplianceStatusSnapshot.StatusRow(label: "明るさ", value: state.brightness?.isEmpty == false ? state.brightness! : "-"),
        ApplianceStatusSnapshot.StatusRow(label: "最後の操作", value: localizedLightButton(state.lastButton))
    ]

    rows.removeAll { $0.value == "-" }

    return ApplianceStatusSnapshot(
        title: localizedPowerState(state.power),
        subtitle: "Nature Remoが保持しているライト状態",
        tone: tone,
        rows: rows,
        isAvailable: true,
        updatedAt: nil
    )
}

private func tvStatusSnapshot(_ state: RemoTVState) -> ApplianceStatusSnapshot {
    let input = state.input?.isEmpty == false ? state.input! : "-"
    return ApplianceStatusSnapshot(
        title: input == "-" ? "入力不明" : "入力 \(input)",
        subtitle: "Nature Remoが保持しているTV状態",
        tone: input == "-" ? .warning : .neutral,
        rows: [ApplianceStatusSnapshot.StatusRow(label: "入力", value: input, tone: input == "-" ? .warning : .neutral)],
        isAvailable: input != "-",
        updatedAt: nil
    )
}

private func airconTone(for mode: String?) -> StatusTone {
    guard let mode else {
        return .neutral
    }

    switch mode.lowercased() {
    case "cool":
        return .cooling
    case "warm", "heat":
        return .heating
    case "dry":
        return .drying
    case "blow", "fan":
        return .fan
    case "auto":
        return .active
    default:
        return .neutral
    }
}

private func statusTone(forPower power: String?) -> StatusTone {
    guard let power else {
        return .warning
    }

    switch power.lowercased() {
    case "on":
        return .active
    case "off", "power-off":
        return .inactive
    default:
        return .neutral
    }
}

private func localizedMatterState(_ state: String) -> String {
    switch state.lowercased() {
    case "on":
        return "オン"
    case "off":
        return "オフ"
    default:
        return state
    }
}

private func formattedStatusDate(_ rawValue: String?) -> String? {
    guard let rawValue, rawValue.isEmpty == false else {
        return nil
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = isoFormatter.date(from: rawValue) ?? ISO8601DateFormatter().date(from: rawValue)

    guard let date else {
        return rawValue
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
