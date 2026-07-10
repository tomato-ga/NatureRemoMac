import SwiftUI

struct ApplianceStatusView: View {
    let appliance: RemoAppliance

    private var snapshot: ApplianceStatusSnapshot {
        applianceStatusSnapshot(for: appliance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(
                title: "現在の状態",
                systemImage: snapshot.isAvailable ? "waveform.path.ecg.rectangle" : "questionmark.circle",
                subtitle: snapshot.subtitle,
                tint: snapshot.tone.color
            )

            HStack(alignment: .center, spacing: 10) {
                StatusBadge(text: snapshot.title, tone: snapshot.tone)

                if let updatedAt = snapshot.updatedAt {
                    Text("更新 \(updatedAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                ForEach(snapshot.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(row.tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(row.tone.color.opacity(0.25), lineWidth: 0.5)
                    }
                }
            }
        }
        .modernPanel()
    }
}

struct ApplianceStatusCardView: View {
    let appliance: RemoAppliance

    private var snapshot: ApplianceStatusSnapshot {
        applianceStatusSnapshot(for: appliance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: applianceIconName(for: appliance), tint: snapshot.tone.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appliance.nickname)
                        .font(.headline)
                        .lineLimit(1)
                    Text(appliance.displayType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            StatusBadge(text: snapshot.title, tone: snapshot.tone)

            Text(snapshot.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .modernPanel(padding: 14)
    }
}
