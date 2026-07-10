import SwiftUI

struct LightControlView: View {
    @EnvironmentObject private var store: RemoStore
    let appliance: RemoAppliance

    var body: some View {
        VStack(spacing: 30) {
            lightDial
            bottomActions
            pageDots
        }
        .frame(maxWidth: 560)
        .padding(.top, 8)
    }

    private var lightDial: some View {
        ZStack {
            Circle()
                .fill(NaturePalette.softSurface.opacity(0.74))
                .frame(width: 330, height: 330)

            Circle()
                .fill(NaturePalette.canvas)
                .frame(width: 174, height: 174)

            dialButton(firstButton(matching: [.exact("bright-up"), .exact("brightness-up"), .contains("bright"), .contains("up")])) {
                Image(systemName: "plus")
                    .font(.system(size: 31, weight: .semibold))
            }
            .offset(y: -122)

            dialButton(firstButton(matching: [.exact("bright-down"), .exact("brightness-down"), .contains("dark"), .contains("down")])) {
                Image(systemName: "minus")
                    .font(.system(size: 31, weight: .semibold))
            }
            .offset(y: 122)

            dialButton(firstButton(matching: [.contains("cool"), .contains("blue"), .contains("temp-down")]), tint: .cyan) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 24, weight: .semibold))
            }
            .offset(x: -122)

            dialButton(firstButton(matching: [.contains("warm"), .contains("orange"), .contains("temp-up")]), tint: .orange) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 24, weight: .semibold))
            }
            .offset(x: 122)

            CircleRemoteButton(size: 82, foreground: NaturePalette.ink, background: NaturePalette.surface) {
                send(firstButton(matching: [.exact("on"), .exact("power-on")]))
            } content: {
                Text("ON")
                    .font(.headline.weight(.bold))
            }
        }
        .accessibilityLabel("ライト操作")
    }

    private var bottomActions: some View {
        HStack(spacing: 118) {
            labeledCircleButton(title: "消灯", text: "OFF", button: firstButton(matching: [.exact("off"), .exact("power-off")]))
            labeledCircleButton(
                title: "常夜灯",
                systemImage: "moon.fill",
                button: firstButton(matching: [.exact("night"), .exact("night-light"), .contains("night"), .contains("sleep"), .contains("small")])
            )
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NaturePalette.ink)
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color(red: 0.720, green: 0.760, blue: 0.750))
                .frame(width: 8, height: 8)
        }
        .padding(.top, 84)
    }

    private func labeledCircleButton(title: String, text: String, button: RemoLightButton?) -> some View {
        VStack(spacing: 10) {
            CircleRemoteButton(size: 84, foreground: button == nil ? NaturePalette.muted.opacity(0.35) : NaturePalette.ink, background: NaturePalette.surface) {
                send(button)
            } content: {
                Text(text)
                    .font(.headline.weight(.bold))
            }
            .disabled(button == nil)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(NaturePalette.muted)
        }
    }

    private func labeledCircleButton(title: String, systemImage: String, button: RemoLightButton?) -> some View {
        VStack(spacing: 10) {
            CircleRemoteButton(size: 84, foreground: button == nil ? NaturePalette.muted.opacity(0.35) : NaturePalette.ink, background: NaturePalette.surface) {
                send(button)
            } content: {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
            }
            .disabled(button == nil)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(NaturePalette.muted)
        }
    }

    private func dialButton<Content: View>(_ button: RemoLightButton?, tint: Color = NaturePalette.ink, @ViewBuilder content: () -> Content) -> some View {
        Button {
            send(button)
        } label: {
            content()
                .foregroundStyle(button == nil ? tint.opacity(0.28) : tint)
                .frame(width: 72, height: 72)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(button == nil)
    }

    private func send(_ button: RemoLightButton?) {
        guard let button else {
            return
        }

        Task {
            await store.sendLightButton(button, appliance: appliance)
        }
    }

    private func firstButton(matching rules: [ButtonRule]) -> RemoLightButton? {
        lightButtons.first { button in
            rules.contains { rule in
                rule.matches(button)
            }
        }
    }

    private var lightButtons: [RemoLightButton] {
        appliance.light?.buttons ?? []
    }
}

private enum ButtonRule {
    case exact(String)
    case contains(String)

    func matches(_ button: RemoLightButton) -> Bool {
        switch self {
        case .exact(let value):
            return button.normalizedName == value
        case .contains(let value):
            return button.normalizedName.contains(value) || button.displayName.lowercased().contains(value)
        }
    }
}
