import SwiftUI

struct TVControlView: View {
    @EnvironmentObject private var store: RemoStore
    let appliance: RemoAppliance

    var body: some View {
        VStack(spacing: 18) {
            if let tvSubtitle {
                Text(tvSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NaturePalette.muted)
            }

            if tvButtons.isEmpty {
                Text("Nature RemoからTVボタンが返っていません。")
                    .foregroundStyle(NaturePalette.muted)
            } else {
                remoteFace
            }
        }
        .frame(maxWidth: 620)
        .padding(.top, 12)
    }

    private var remoteFace: some View {
        VStack(spacing: 18) {
            topControls

            HStack(alignment: .center, spacing: 26) {
                verticalControl(
                    top: button(matching: [.exact("vol-up"), .contains("volume-up"), .contains("音量+")]),
                    bottom: button(matching: [.exact("vol-down"), .contains("volume-down"), .contains("音量-")]),
                    label: "音量",
                    topIcon: "plus",
                    bottomIcon: "minus"
                )

                dPad

                verticalControl(
                    top: button(matching: [.exact("ch-up"), .contains("channel-up"), .contains("チャンネル+")]),
                    bottom: button(matching: [.exact("ch-down"), .contains("channel-down"), .contains("チャンネル-")]),
                    label: "チャンネル",
                    topIcon: "chevron.up",
                    bottomIcon: "chevron.down"
                )
            }

            numberPad
            utilityRows
        }
        .padding(22)
        .background(NaturePalette.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(NaturePalette.divider, lineWidth: 0.5)
        }
        .shadow(color: NaturePalette.ink.opacity(0.035), radius: 10, y: 4)
    }

    private var topControls: some View {
        HStack(spacing: 18) {
            remoteCircle(
                button: button(matching: [.exact("power")]),
                systemImage: "power",
                tint: NaturePalette.mint,
                accessibilityLabel: "電源"
            )

            remoteCapsule(
                button: button(matching: [.exact("input"), .contains("source")]),
                title: "入力切替",
                systemImage: "rectangle.on.rectangle"
            )

            remoteCircle(
                button: button(matching: [.exact("mute"), .contains("消音")]),
                systemImage: "speaker.slash",
                tint: NaturePalette.ink,
                accessibilityLabel: "消音"
            )
        }
    }

    private var dPad: some View {
        ZStack {
            Circle()
                .fill(NaturePalette.softSurface.opacity(0.68))
                .frame(width: 210, height: 210)

            remoteDPadButton(button: button(matching: [.exact("up")]), systemImage: "chevron.up")
                .offset(y: -70)
            remoteDPadButton(button: button(matching: [.exact("down")]), systemImage: "chevron.down")
                .offset(y: 70)
            remoteDPadButton(button: button(matching: [.exact("left")]), systemImage: "chevron.left")
                .offset(x: -70)
            remoteDPadButton(button: button(matching: [.exact("right")]), systemImage: "chevron.right")
                .offset(x: 70)

            CircleRemoteButton(size: 72, foreground: NaturePalette.ink, background: NaturePalette.surface) {
                send(button(matching: [.exact("ok"), .exact("enter")]))
            } content: {
                Text("OK")
                    .font(.headline.weight(.bold))
            }
            .disabled(button(matching: [.exact("ok"), .exact("enter")]) == nil)
        }
    }

    private var numberPad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 54), spacing: 10), count: 4), spacing: 10) {
            ForEach(numberButtons, id: \.0) { number, remoteButton in
                RoundedRemoteButton(minHeight: 48) {
                    send(remoteButton)
                } content: {
                    Text("\(number)")
                        .font(.headline.weight(.semibold))
                }
                .disabled(remoteButton == nil)
                .opacity(remoteButton == nil ? 0.35 : 1)
            }
        }
    }

    private var utilityRows: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                remoteUtility(button: button(matching: [.exact("home")]), title: "ホーム", systemImage: "house")
                remoteUtility(button: button(matching: [.exact("menu")]), title: "メニュー", systemImage: "list.bullet")
                remoteUtility(button: button(matching: [.exact("guide")]), title: "番組表", systemImage: "calendar")
                remoteUtility(button: button(matching: [.exact("back"), .exact("return")]), title: "戻る", systemImage: "arrow.uturn.backward")
            }

            HStack(spacing: 10) {
                remoteUtility(button: button(matching: [.exact("play")]), title: "再生", systemImage: "play.fill")
                remoteUtility(button: button(matching: [.exact("pause")]), title: "一時停止", systemImage: "pause.fill")
                remoteUtility(button: button(matching: [.exact("stop")]), title: "停止", systemImage: "stop.fill")
                remoteUtility(button: button(matching: [.exact("record")]), title: "録画", systemImage: "record.circle")
            }
        }
    }

    private func verticalControl(top: RemoLightButton?, bottom: RemoLightButton?, label: String, topIcon: String, bottomIcon: String) -> some View {
        VStack(spacing: 8) {
            CircleRemoteButton(size: 58, foreground: top == nil ? NaturePalette.muted.opacity(0.35) : NaturePalette.ink, background: NaturePalette.surface) {
                send(top)
            } content: {
                Image(systemName: topIcon)
            }
            .disabled(top == nil)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(NaturePalette.muted)

            CircleRemoteButton(size: 58, foreground: bottom == nil ? NaturePalette.muted.opacity(0.35) : NaturePalette.ink, background: NaturePalette.surface) {
                send(bottom)
            } content: {
                Image(systemName: bottomIcon)
            }
            .disabled(bottom == nil)
        }
    }

    private func remoteCircle(button: RemoLightButton?, systemImage: String, tint: Color, accessibilityLabel: String) -> some View {
        CircleRemoteButton(size: 64, foreground: button == nil ? NaturePalette.muted.opacity(0.35) : tint, background: NaturePalette.surface) {
            send(button)
        } content: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
        }
        .disabled(button == nil)
        .accessibilityLabel(accessibilityLabel)
    }

    private func remoteCapsule(button: RemoLightButton?, title: String, systemImage: String) -> some View {
        RoundedRemoteButton(minHeight: 54) {
            send(button)
        } content: {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 10)
        }
        .frame(width: 180)
        .disabled(button == nil)
        .opacity(button == nil ? 0.35 : 1)
    }

    private func remoteDPadButton(button: RemoLightButton?, systemImage: String) -> some View {
        Button {
            send(button)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(button == nil ? NaturePalette.muted.opacity(0.35) : NaturePalette.ink)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(button == nil)
    }

    private func remoteUtility(button: RemoLightButton?, title: String, systemImage: String) -> some View {
        RoundedRemoteButton(minHeight: 46) {
            send(button)
        } content: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .disabled(button == nil)
        .opacity(button == nil ? 0.35 : 1)
    }

    private var numberButtons: [(Int, RemoLightButton?)] {
        (1...12).map { number in
            (number, button(matching: [.exact("\(number)"), .exact("ch-\(number)")]))
        }
    }

    private var tvButtons: [RemoLightButton] {
        appliance.tv?.buttons ?? []
    }

    private var tvSubtitle: String? {
        guard let input = appliance.tv?.state?.input, input.isEmpty == false else {
            return nil
        }
        return "現在の入力: \(input)"
    }

    private func button(matching rules: [TVButtonRule]) -> RemoLightButton? {
        tvButtons.first { button in
            rules.contains { rule in
                rule.matches(button)
            }
        }
    }

    private func send(_ button: RemoLightButton?) {
        guard let button else {
            return
        }

        Task {
            await store.sendTVButton(button, appliance: appliance)
        }
    }
}

private enum TVButtonRule {
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
