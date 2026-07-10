import AppKit
import SwiftUI

struct RemoMenuBarView: View {
    @EnvironmentObject private var store: RemoStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Dashboard") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Settings") {
            openAppSettings()
        }

        Divider()

        if store.tokenIsConfigured == false {
            Label("Token Required", systemImage: "key")
        } else {
            Button("Refresh") {
                Task { await store.refresh() }
            }

            if store.quickLightButtons.isEmpty == false || store.quickTVButtons.isEmpty == false || store.quickSignals.isEmpty == false {
                Divider()
                ForEach(store.quickLightButtons.prefix(6)) { quickLightButton in
                    Button(shortMenuTitle("\(quickLightButton.appliance.nickname) \(quickLightButton.button.displayName)")) {
                        Task {
                            await store.sendLightButton(quickLightButton.button, appliance: quickLightButton.appliance)
                        }
                    }
                }

                ForEach(store.quickTVButtons.prefix(6)) { quickTVButton in
                    Button(shortMenuTitle("\(quickTVButton.appliance.nickname) \(localizedTVButtonName(quickTVButton.button))")) {
                        Task {
                            await store.sendTVButton(quickTVButton.button, appliance: quickTVButton.appliance)
                        }
                    }
                }

                ForEach(store.quickSignals.prefix(8)) { quickSignal in
                    Button(shortMenuTitle("\(quickSignal.appliance.nickname) \(quickSignal.signal.name)")) {
                        Task {
                            await store.send(signal: quickSignal.signal, applianceName: quickSignal.appliance.nickname)
                        }
                    }
                }
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
