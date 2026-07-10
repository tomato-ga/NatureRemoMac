import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: RemoStore
    @State private var token = ""

    var body: some View {
        TabView {
            Form {
                Section {
                    Text("API Access")
                        .font(.headline)

                    SecureField("Personal access token", text: $token)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button {
                            Task {
                                await store.saveTokenAndRefresh(token)
                                token = ""
                            }
                        } label: {
                            Label("Save Token", systemImage: "key.fill")
                        }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("Validate", systemImage: "checkmark.seal")
                        }
                        .disabled(!store.tokenIsConfigured)

                        Button(role: .destructive) {
                            store.clearToken()
                            token = ""
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .disabled(!store.tokenIsConfigured)
                    }
                }

                Section {
                    Text("Status")
                        .font(.headline)

                    LabeledContent("Account", value: store.user?.nickname ?? "-")
                    LabeledContent("Appliances", value: "\(store.appliances.count)")
                    LabeledContent("Devices", value: "\(store.devices.count)")
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("API", systemImage: "network")
            }
        }
        .frame(width: 520, height: 320)
    }
}
