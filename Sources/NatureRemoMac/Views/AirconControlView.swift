import SwiftUI

struct AirconControlView: View {
    @EnvironmentObject private var store: RemoStore
    let appliance: RemoAppliance

    @State private var temperature: String
    @State private var operationMode: String
    @State private var airVolume: String
    @State private var airDirection: String
    @State private var horizontalDirection: String
    @State private var powerIsOn: Bool
    @State private var dragStartTemperature: String?

    init(appliance: RemoAppliance) {
        self.appliance = appliance

        let initialMode = appliance.settings?.mode
            ?? appliance.aircon?.range?.modes.keys.sorted().first
            ?? "cool"
        let modeRange = appliance.aircon?.range?.modes[initialMode]

        _operationMode = State(initialValue: initialMode)
        _temperature = State(initialValue: appliance.settings?.temperature ?? modeRange?.temp.first ?? "26")
        _airVolume = State(initialValue: appliance.settings?.volume ?? modeRange?.vol.first ?? "")
        _airDirection = State(initialValue: appliance.settings?.direction ?? modeRange?.dir.first ?? "")
        _horizontalDirection = State(initialValue: appliance.settings?.horizontalDirection ?? modeRange?.dirh.first ?? "")
        _powerIsOn = State(initialValue: appliance.settings?.button?.lowercased() != "power-off")
    }

    var body: some View {
        VStack(spacing: 24) {
            sensorHeader

            HStack(alignment: .center, spacing: 26) {
                CircleRemoteButton(size: 48, foreground: NaturePalette.ink, background: NaturePalette.surface) {
                    stepTemperature(by: -1)
                    sendCurrentSettings(powerOn: true)
                } content: {
                    Image(systemName: "minus")
                }
                .disabled(canStepTemperature(by: -1) == false)

                temperatureCard

                CircleRemoteButton(size: 48, foreground: NaturePalette.ink, background: NaturePalette.surface) {
                    stepTemperature(by: 1)
                    sendCurrentSettings(powerOn: true)
                } content: {
                    Image(systemName: "plus")
                }
                .disabled(canStepTemperature(by: 1) == false)
            }

            powerButton
            modeSelector
            detailTiles
        }
        .frame(maxWidth: 680)
        .padding(.top, 4)
    }

    private var sensorHeader: some View {
        VStack(spacing: 6) {
            Text(appliance.device?.name ?? appliance.nickname)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NaturePalette.muted)

            if let roomTemperatureText {
                Label(roomTemperatureText, systemImage: "thermometer")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(NaturePalette.muted)
            }
        }
        .frame(height: 52)
    }

    private var temperatureCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22)
                .fill(NaturePalette.softSurface)

            RoundedRectangle(cornerRadius: 22)
                .fill(powerIsOn ? cardFillColor : NaturePalette.softSurface)
                .frame(height: cardFillHeight)
                .opacity(powerIsOn ? 1 : 0.52)

            VStack(spacing: 6) {
                Capsule()
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 42, height: 6)
                    .padding(.top, 34)

                Spacer()

                Text("設定温度")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(powerIsOn ? NaturePalette.muted : NaturePalette.muted.opacity(0.55))

                Text(temperatureDisplay)
                    .font(.system(size: 44, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(powerIsOn ? NaturePalette.ink.opacity(0.72) : NaturePalette.muted.opacity(0.45))
                    .minimumScaleFactor(0.72)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 164, height: 258)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    updateTemperatureFromDrag(translationHeight: value.translation.height)
                }
                .onEnded { _ in
                    commitTemperatureDrag()
                }
        )
        .accessibilityLabel("設定温度 \(temperatureDisplay)")
    }

    private var powerButton: some View {
        CircleRemoteButton(
            size: 68,
            foreground: powerIsOn ? NaturePalette.mint : NaturePalette.muted,
            background: NaturePalette.surface,
            border: powerIsOn ? NaturePalette.mint : Color.clear,
            borderWidth: powerIsOn ? 2 : 0
        ) {
            if powerIsOn {
                powerIsOn = false
                sendPowerOff()
            } else {
                sendCurrentSettings(powerOn: true)
            }
        } content: {
            Image(systemName: "power")
                .font(.system(size: 30, weight: .regular))
        }
        .accessibilityLabel(powerIsOn ? "電源オフ" : "電源オン")
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(primaryModeOptions, id: \.self) { mode in
                Button {
                    operationMode = mode
                    normalizeSelectionsForMode()
                    sendCurrentSettings(powerOn: true)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: modeIconName(mode))
                            .font(.system(size: 16, weight: .semibold))
                        Text(airconModeLabel(mode))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(operationMode == mode ? Color.white : NaturePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(operationMode == mode ? NaturePalette.selection : NaturePalette.surface)
                }
                .buttonStyle(.plain)

                if mode != primaryModeOptions.last {
                    Rectangle()
                        .fill(NaturePalette.divider)
                        .frame(width: 1, height: 46)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: NaturePalette.ink.opacity(0.025), radius: 8, y: 2)
    }

    private var detailTiles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 16) {
            controlTile(title: "風量", value: airVolumeLabel(airVolume), systemImage: "fanblades.fill") {
                cycleSelection($airVolume, options: volumeOptions)
                sendCurrentSettings(powerOn: true)
            }

            controlTile(title: "上下風向", value: airDirectionLabel(airDirection), systemImage: "wind") {
                cycleSelection($airDirection, options: directionOptions)
                sendCurrentSettings(powerOn: true)
            }

            if horizontalOptions.isEmpty == false {
                controlTile(title: "左右風向", value: airDirectionLabel(horizontalDirection), systemImage: "arrow.left.and.right") {
                    cycleSelection($horizontalDirection, options: horizontalOptions)
                    sendCurrentSettings(powerOn: true)
                }
            }

            ForEach(extraFixedButtons, id: \.self) { button in
                controlTile(title: fixedButtonLabel(button), value: "", systemImage: fixedButtonIcon(button)) {
                    powerIsOn = true
                    sendButton(button)
                }
            }
        }
        .frame(maxWidth: 520)
    }

    private func controlTile(title: String, value: String, systemImage: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            RoundedRemoteButton(minHeight: 74, action: action) {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                    if value.isEmpty == false {
                        Text(value)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(NaturePalette.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
    }

    private var selectedModeRange: RemoAirconModeRange? {
        appliance.aircon?.range?.modes[operationMode]
    }

    private var roomTemperatureText: String? {
        guard let deviceID = appliance.device?.id,
              let value = store.devices.first(where: { $0.id == deviceID })?.newestEvents["te"]?.value else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return "\(formatter.string(from: NSNumber(value: value)) ?? "\(value)")°"
    }

    private var cardFillColor: Color {
        switch operationMode.lowercased() {
        case "warm", "heat":
            return NaturePalette.warm
        case "cool":
            return NaturePalette.cool
        case "dry":
            return Color(red: 0.780, green: 0.910, blue: 0.880)
        case "blow", "fan":
            return Color(red: 0.850, green: 0.925, blue: 0.965)
        default:
            return Color(red: 0.890, green: 0.930, blue: 0.900)
        }
    }

    private var cardFillHeight: CGFloat {
        let options = temperatureOptions.compactMap(Double.init)
        guard let current = Double(temperature),
              let min = options.min(),
              let max = options.max(),
              max > min else {
            return 138
        }

        let ratio = (current - min) / (max - min)
        return 90 + CGFloat(ratio) * 132
    }

    private var primaryModeOptions: [String] {
        let preferred = ["cool", "dry", "warm", "heat", "auto", "blow", "fan"]
        var resolved: [String] = []

        for preferredMode in preferred {
            guard let match = modeOptions.first(where: { $0.lowercased() == preferredMode }) else {
                continue
            }
            if resolved.contains(match) == false {
                resolved.append(match)
            }
        }

        return resolved.isEmpty ? Array(modeOptions.prefix(4)) : Array(resolved.prefix(4))
    }

    private var modeOptions: [String] {
        let values = appliance.aircon?.range?.modes.keys.sorted() ?? []
        return includeCurrent(operationMode, in: orderedModes(values.isEmpty ? ["auto", "cool", "warm", "dry", "blow"] : values))
    }

    private var temperatureOptions: [String] {
        numericSort(includeCurrent(temperature, in: selectedModeRange?.temp ?? (18...30).map(String.init)))
    }

    private var volumeOptions: [String] {
        includeCurrent(airVolume, in: selectedModeRange?.vol ?? ["", "1", "2", "3", "4", "5"])
    }

    private var directionOptions: [String] {
        includeCurrent(airDirection, in: selectedModeRange?.dir ?? ["", "1", "2", "3", "4", "5"])
    }

    private var horizontalOptions: [String] {
        includeCurrent(horizontalDirection, in: selectedModeRange?.dirh ?? [])
    }

    private var extraFixedButtons: [String] {
        (appliance.aircon?.range?.fixedButtons ?? [])
            .filter { $0.lowercased() != "power-off" }
            .prefix(4)
            .map { $0 }
    }

    private var temperatureDisplay: String {
        temperature.isEmpty ? "-" : "\(temperature)°"
    }

    private func includeCurrent(_ current: String, in values: [String]) -> [String] {
        if values.contains(current) {
            return values
        }
        if current.isEmpty, values.contains("auto") {
            return values
        }
        return current.isEmpty && values.isEmpty == false ? values : [current] + values
    }

    private func normalizeSelectionsForMode() {
        if temperatureOptions.contains(temperature) == false {
            temperature = temperatureOptions.first ?? temperature
        }
        if volumeOptions.contains(airVolume) == false {
            airVolume = volumeOptions.first ?? airVolume
        }
        if directionOptions.contains(airDirection) == false {
            airDirection = directionOptions.first ?? airDirection
        }
        if horizontalOptions.isEmpty == false && horizontalOptions.contains(horizontalDirection) == false {
            horizontalDirection = horizontalOptions.first ?? horizontalDirection
        }
    }

    private func stepTemperature(by delta: Int) {
        guard let next = steppedValue(current: temperature, in: temperatureOptions, by: delta) else {
            return
        }
        temperature = next
    }

    private func updateTemperatureFromDrag(translationHeight: CGFloat) {
        if dragStartTemperature == nil {
            dragStartTemperature = temperature
        }

        guard let startTemperature = dragStartTemperature else {
            return
        }

        let stepCount = Int((-translationHeight / 18).rounded())
        temperature = temperatureByOffset(from: startTemperature, offset: stepCount) ?? temperature
    }

    private func commitTemperatureDrag() {
        defer { dragStartTemperature = nil }

        guard let dragStartTemperature, dragStartTemperature != temperature else {
            return
        }

        sendCurrentSettings(powerOn: true)
    }

    private func canStepTemperature(by delta: Int) -> Bool {
        steppedValue(current: temperature, in: temperatureOptions, by: delta) != nil
    }

    private func steppedValue(current: String, in options: [String], by delta: Int) -> String? {
        guard options.isEmpty == false else {
            return nil
        }

        if let index = options.firstIndex(of: current) {
            let nextIndex = index + delta
            guard options.indices.contains(nextIndex) else {
                return nil
            }
            return options[nextIndex]
        }

        guard let currentValue = Double(current) else {
            return options.first
        }

        if delta > 0 {
            return options.first { (Double($0) ?? currentValue) > currentValue }
        }

        return options.last { (Double($0) ?? currentValue) < currentValue }
    }

    private func temperatureByOffset(from start: String, offset: Int) -> String? {
        let options = temperatureOptions
        guard options.isEmpty == false else {
            return nil
        }

        let startIndex = options.firstIndex(of: start) ?? nearestTemperatureIndex(to: start, in: options)
        let targetIndex = min(max(startIndex + offset, options.startIndex), options.index(before: options.endIndex))
        return options[targetIndex]
    }

    private func nearestTemperatureIndex(to value: String, in options: [String]) -> Int {
        guard let target = Double(value) else {
            return options.startIndex
        }

        return options.indices.min { left, right in
            abs((Double(options[left]) ?? target) - target) < abs((Double(options[right]) ?? target) - target)
        } ?? options.startIndex
    }

    private func cycleSelection(_ selection: Binding<String>, options: [String]) {
        guard options.isEmpty == false else {
            return
        }

        guard let index = options.firstIndex(of: selection.wrappedValue) else {
            selection.wrappedValue = options.first ?? selection.wrappedValue
            return
        }

        selection.wrappedValue = options[(index + 1) % options.count]
    }

    private func sendCurrentSettings(powerOn: Bool) {
        powerIsOn = powerOn
        Task {
            await store.setAircon(appliance: appliance, form: airconForm(button: ""))
        }
    }

    private func sendPowerOff() {
        Task {
            await store.setAircon(appliance: appliance, form: airconForm(button: "power-off"))
        }
    }

    private func sendButton(_ button: String) {
        Task {
            await store.setAircon(appliance: appliance, form: airconForm(button: button))
        }
    }

    private func airconForm(button: String) -> [String: String] {
        [
            "temperature": temperature,
            "temperature_unit": appliance.settings?.temperatureUnit ?? appliance.aircon?.tempUnit ?? "c",
            "operation_mode": operationMode,
            "air_volume": airVolume,
            "air_direction": airDirection,
            "air_direction_h": horizontalDirection,
            "button": button
        ]
    }

    private func orderedModes(_ values: [String]) -> [String] {
        let preferred = ["auto", "cool", "dry", "warm", "heat", "blow", "fan"]
        let preferredModes = preferred.filter { preferred in
            values.contains { $0.lowercased() == preferred }
        }
        let remaining = values.filter { value in
            preferred.contains(value.lowercased()) == false
        }.sorted()
        return preferredModes + remaining
    }

    private func numericSort(_ values: [String]) -> [String] {
        values.sorted {
            switch (Double($0), Double($1)) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return $0.localizedStandardCompare($1) == .orderedAscending
            }
        }
    }

    private func airconModeLabel(_ mode: String) -> String {
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

    private func airVolumeLabel(_ value: String) -> String {
        value.isEmpty || value.lowercased() == "auto" ? "Auto" : value
    }

    private func airDirectionLabel(_ value: String) -> String {
        value.isEmpty || value.lowercased() == "auto" ? "Auto" : value
    }

    private func modeIconName(_ mode: String) -> String {
        switch mode.lowercased() {
        case "auto":
            return "arrow.triangle.2.circlepath"
        case "cool":
            return "snowflake"
        case "warm", "heat":
            return "flame.fill"
        case "dry":
            return "drop.fill"
        case "blow", "fan":
            return "fanblades.fill"
        default:
            return "circle"
        }
    }

    private func fixedButtonLabel(_ button: String) -> String {
        switch button.lowercased() {
        case "clean", "cleaning", "internal-clean":
            return "内部クリーン"
        case "eco":
            return "Eco"
        case "airdir":
            return "風向"
        case "airvolume":
            return "風量"
        default:
            return button
        }
    }

    private func fixedButtonIcon(_ button: String) -> String {
        switch button.lowercased() {
        case "clean", "cleaning", "internal-clean":
            return "sparkles"
        case "eco":
            return "leaf"
        default:
            return "bolt.circle"
        }
    }
}
