import SwiftUI

struct TokenSetupView: View {
    @EnvironmentObject private var store: RemoStore
    @State private var token = ""

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                IconBadge(systemName: "key.radiowaves.forward", tint: .accentColor)
                    .scaleEffect(1.25)

                Text("Connect Nature Remo")
                    .font(.title2.weight(.semibold))

                Text("Paste your personal access token to load your appliances.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                SecureField("Personal access token", text: $token)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Link("Open Nature Home", destination: URL(string: "https://home.nature.global/")!)

                    Spacer()

                    Button {
                        Task {
                            await store.saveTokenAndRefresh(token)
                            token = ""
                        }
                    } label: {
                        Label("Save", systemImage: "key.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .modernPanel()
            .frame(maxWidth: 480)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
