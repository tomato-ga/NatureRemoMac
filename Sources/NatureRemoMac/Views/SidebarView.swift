import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: RemoStore

    var body: some View {
        VStack(spacing: 0) {
            connectionHeader
                .padding()

            Divider()

            if store.tokenIsConfigured {
                List(selection: $store.selectedApplianceID) {
                    Section("Appliances") {
                        ForEach(store.appliances) { appliance in
                            ApplianceRowView(appliance: appliance)
                                .tag(appliance.id)
                        }
                    }

                    Section("Sensors") {
                        ForEach(store.devices) { device in
                            Label(device.name, systemImage: "sensor")
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                Spacer()
                Label("Token Required", systemImage: "key")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var connectionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IconBadge(
                    systemName: store.tokenIsConfigured ? "checkmark.seal.fill" : "key.fill",
                    tint: store.tokenIsConfigured ? .green : .secondary
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.user?.nickname ?? "Nature Remo")
                        .font(.headline)
                        .lineLimit(1)
                    Text(store.tokenIsConfigured ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if store.tokenIsConfigured {
                HStack(spacing: 8) {
                    Label("\(store.appliances.count)", systemImage: "powerplug")
                    Label("\(store.devices.count)", systemImage: "sensor")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ApplianceRowView: View {
    let appliance: RemoAppliance

    var body: some View {
        let snapshot = applianceStatusSnapshot(for: appliance)

        HStack(spacing: 10) {
            Image(systemName: applianceIconName(for: appliance))
                .foregroundStyle(snapshot.tone.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(appliance.nickname)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(appliance.displayType)
                    Text("·")
                    StatusDot(tone: snapshot.tone)
                    Text(snapshot.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}
