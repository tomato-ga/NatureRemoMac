import SwiftUI

enum NaturePalette {
    static let canvas = Color(red: 0.965, green: 0.970, blue: 0.978)
    static let surface = Color.white
    static let softSurface = Color(red: 0.925, green: 0.935, blue: 0.945)
    static let ink = Color(red: 0.000, green: 0.120, blue: 0.160)
    static let muted = Color(red: 0.520, green: 0.560, blue: 0.590)
    static let selection = Color(red: 0.000, green: 0.145, blue: 0.185)
    static let mint = Color(red: 0.220, green: 0.780, blue: 0.620)
    static let warm = Color(red: 1.000, green: 0.840, blue: 0.330)
    static let cool = Color(red: 0.870, green: 0.925, blue: 0.960)
    static let divider = Color(red: 0.875, green: 0.890, blue: 0.905)
}

struct IconBadge: View {
    let systemName: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct PanelHeader: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(systemName: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct StatusBadge: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Label(text, systemImage: tone.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tone.color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tone.color.opacity(0.35), lineWidth: 0.5)
            }
    }
}

struct StatusDot: View {
    let tone: StatusTone

    var body: some View {
        Circle()
            .fill(tone.color)
            .frame(width: 7, height: 7)
    }
}

struct ModernPanelModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(NaturePalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(NaturePalette.divider, lineWidth: 0.5)
            }
    }
}

struct CircleRemoteButton<Content: View>: View {
    var size: CGFloat = 72
    var foreground: Color = NaturePalette.ink
    var background: Color = NaturePalette.surface
    var border: Color = .clear
    var borderWidth: CGFloat = 0
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .overlay {
                    Circle()
                        .stroke(border, lineWidth: borderWidth)
                }
                .shadow(color: NaturePalette.ink.opacity(0.035), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct RoundedRemoteButton<Content: View>: View {
    var isSelected = false
    var minHeight: CGFloat = 52
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(isSelected ? Color.white : NaturePalette.ink)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(isSelected ? NaturePalette.selection : NaturePalette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : NaturePalette.divider, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func modernPanel(padding: CGFloat = 16) -> some View {
        modifier(ModernPanelModifier(padding: padding))
    }
}

func applianceIconName(for appliance: RemoAppliance) -> String {
    if appliance.aircon != nil {
        return "wind"
    }
    if appliance.isLight {
        return "lightbulb"
    }
    if appliance.isTV {
        return "tv"
    }
    return "powerplug"
}

func applianceTint(for appliance: RemoAppliance) -> Color {
    if appliance.aircon != nil {
        return .cyan
    }
    if appliance.isLight {
        return .yellow
    }
    if appliance.isTV {
        return .purple
    }
    return .accentColor
}
