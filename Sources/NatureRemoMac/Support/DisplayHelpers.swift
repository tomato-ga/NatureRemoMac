import Foundation

func shortMenuTitle(_ title: String) -> String {
    if title.count <= 30 {
        return title
    }
    return String(title.prefix(27)) + "..."
}

func eventDisplayName(for key: String) -> String {
    switch key {
    case "te":
        return "Temperature"
    case "hu":
        return "Humidity"
    case "il":
        return "Illuminance"
    case "mo":
        return "Motion"
    default:
        return key.uppercased()
    }
}

func eventDisplayValue(key: String, value: Double?) -> String {
    guard let value else {
        return "-"
    }

    switch key {
    case "te":
        return "\(formatNumber(value)) C"
    case "hu":
        return "\(formatNumber(value))%"
    case "il":
        return "\(formatNumber(value)) lx"
    default:
        return formatNumber(value)
    }
}

func localizedTVButtonName(_ button: RemoLightButton) -> String {
    switch button.normalizedName {
    case "power":
        return "電源"
    case "input":
        return "入力切替"
    case "mute":
        return "消音"
    case "vol-up":
        return "音量 +"
    case "vol-down":
        return "音量 -"
    case "ch-up":
        return "チャンネル +"
    case "ch-down":
        return "チャンネル -"
    case "up":
        return "上"
    case "down":
        return "下"
    case "left":
        return "左"
    case "right":
        return "右"
    case "ok", "enter":
        return "決定"
    case "back", "return":
        return "戻る"
    case "home":
        return "ホーム"
    case "menu":
        return "メニュー"
    case "guide":
        return "番組表"
    case "info":
        return "情報"
    case "play":
        return "再生"
    case "pause":
        return "一時停止"
    case "stop":
        return "停止"
    case "rewind":
        return "巻戻し"
    case "fast-forward":
        return "早送り"
    case "record":
        return "録画"
    case "terrestrial":
        return "地デジ"
    case "bs":
        return "BS"
    case "cs":
        return "CS"
    case "d", "data":
        return "d"
    case let name where name.hasPrefix("ch-"):
        return String(name.dropFirst(3))
    default:
        return button.displayName.isEmpty ? button.name : button.displayName
    }
}

private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
