import SwiftUI

struct ApplianceDetailView: View {
    @EnvironmentObject private var store: RemoStore
    let appliance: RemoAppliance

    var body: some View {
        ViewThatFits(in: .vertical) {
            content

            ScrollView {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .center, spacing: 18) {
            header

            if appliance.aircon != nil {
                AirconControlView(appliance: appliance)
            }

            if appliance.isLight {
                LightControlView(appliance: appliance)
            }

            if appliance.isTV {
                TVControlView(appliance: appliance)
            }

            if appliance.signals.isEmpty == false {
                signalGrid
            } else if appliance.aircon == nil && appliance.isLight == false && appliance.isTV == false {
                EmptyStateView(title: "No Signals", systemImage: "antenna.radiowaves.left.and.right.slash")
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(NaturePalette.canvas)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(appliance.nickname)
                .font(.title2.weight(.semibold))
                .foregroundStyle(NaturePalette.ink)
                .lineLimit(1)

            HStack(spacing: 8) {
                Image(systemName: applianceIconName(for: appliance))
                    .foregroundStyle(applianceStatusSnapshot(for: appliance).tone.color)
                Text(compactApplianceStatus(for: appliance))
                if let deviceName = appliance.device?.name {
                    Text("・\(deviceName)")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(NaturePalette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var signalGrid: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("その他の操作")
                .font(.headline.weight(.semibold))
                .foregroundStyle(NaturePalette.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(appliance.signals) { signal in
                    RoundedRemoteButton(minHeight: 54) {
                        Task {
                            await store.send(signal: signal, applianceName: appliance.nickname)
                        }
                    } content: {
                        Label(signal.name, systemImage: "dot.radiowaves.left.and.right")
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .frame(maxWidth: 560)
    }
}
