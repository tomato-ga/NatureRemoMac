import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct NatureRemoMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = RemoStore()

    var body: some Scene {
        WindowGroup("Nature Remo", id: "main") {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .task {
                    await store.refreshIfConfigured()
                }
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Appliances") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!store.tokenIsConfigured)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }

        MenuBarExtra("Remo", systemImage: "sensor.tag.radiowaves.forward") {
            RemoMenuBarView()
                .environmentObject(store)
        }
    }
}
