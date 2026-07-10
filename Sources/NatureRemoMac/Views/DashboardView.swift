import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: RemoStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(NaturePalette.ink)
                    Text("Sensors and quick controls")
                        .font(.subheadline)
                        .foregroundStyle(NaturePalette.muted)
                }

                applianceStatusSection
                deviceGrid
                quickSignalSection
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(NaturePalette.canvas)
    }

    @ViewBuilder
    private var applianceStatusSection: some View {
        if store.appliances.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: "Appliances",
                    systemImage: "powerplug",
                    subtitle: "Current status",
                    tint: .accentColor
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                    ForEach(store.appliances) { appliance in
                        ApplianceStatusCardView(appliance: appliance)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedApplianceID = appliance.id
                            }
                    }
                }
            }
        }
    }

    private var deviceGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                title: "Sensors",
                systemImage: "sensor",
                subtitle: store.devices.isEmpty ? nil : "\(store.devices.count) devices",
                tint: .green
            )

            if store.devices.isEmpty {
                EmptyStateView(title: "No sensor devices", systemImage: "sensor")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(store.devices) { device in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(device.name)
                                .font(.headline)
                                .lineLimit(1)

                            if device.newestEvents.isEmpty {
                                Text("No sensor values")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(device.newestEvents.keys.sorted(), id: \.self) { key in
                                    HStack {
                                        Text(eventDisplayName(for: key))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(eventDisplayValue(key: key, value: device.newestEvents[key]?.value))
                                            .font(.headline)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .modernPanel(padding: 14)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quickSignalSection: some View {
        if store.quickLightButtons.isEmpty == false || store.quickTVButtons.isEmpty == false || store.quickSignals.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: "Quick Actions",
                    systemImage: "bolt.fill",
                    subtitle: "Common controls",
                    tint: .orange
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(store.quickLightButtons.prefix(8)) { quickLightButton in
                        RoundedRemoteButton(minHeight: 54) {
                            Task {
                                await store.sendLightButton(quickLightButton.button, appliance: quickLightButton.appliance)
                            }
                        } content: {
                            QuickActionLabel(
                                title: quickLightButton.button.displayName,
                                subtitle: quickLightButton.appliance.nickname,
                                systemImage: "lightbulb.fill",
                                tint: .yellow
                            )
                        }
                    }

                    ForEach(store.quickTVButtons.prefix(8)) { quickTVButton in
                        RoundedRemoteButton(minHeight: 54) {
                            Task {
                                await store.sendTVButton(quickTVButton.button, appliance: quickTVButton.appliance)
                            }
                        } content: {
                            QuickActionLabel(
                                title: localizedTVButtonName(quickTVButton.button),
                                subtitle: quickTVButton.appliance.nickname,
                                systemImage: "tv",
                                tint: .purple
                            )
                        }
                    }

                    ForEach(store.quickSignals.prefix(12)) { quickSignal in
                        RoundedRemoteButton(minHeight: 54) {
                            Task {
                                await store.send(signal: quickSignal.signal, applianceName: quickSignal.appliance.nickname)
                            }
                        } content: {
                            QuickActionLabel(
                                title: quickSignal.signal.name,
                                subtitle: quickSignal.appliance.nickname,
                                systemImage: "dot.radiowaves.left.and.right",
                                tint: applianceTint(for: quickSignal.appliance)
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct QuickActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(NaturePalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NaturePalette.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
