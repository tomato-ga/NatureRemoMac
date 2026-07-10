import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RemoStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 290)
        } detail: {
            detail
        }
        .frame(minWidth: 1040, minHeight: 720)
        .background(NaturePalette.canvas)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!store.tokenIsConfigured || store.isLoading)

                Button {
                    openAppSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .tint(.accentColor)
        .preferredColorScheme(.light)
        .task {
            await store.runApplianceStatePolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await store.refreshApplianceStatesIfConfigured()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            NoticeView()
                .environmentObject(store)
                .padding()
        }
    }

    @ViewBuilder
    private var detail: some View {
        if store.tokenIsConfigured == false {
            TokenSetupView()
        } else if let appliance = store.selectedAppliance {
            ApplianceDetailView(appliance: appliance)
        } else {
            DashboardView()
        }
    }
}
