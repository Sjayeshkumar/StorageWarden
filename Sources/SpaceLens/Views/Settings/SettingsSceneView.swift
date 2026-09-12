import ServiceManagement
import SwiftUI

struct SettingsSceneView: View {
    @ObservedObject var session: AppSession
    @AppStorage("showMenuBarMonitor") private var showMonitor = true
    @AppStorage("introCompleted") private var introCompleted = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    var body: some View {
        Form {
            Section("Background & activity") {
                Toggle("Show menu-bar activity monitor", isOn: $showMonitor)
                Toggle("Refresh changed folders in the background", isOn: $session.backgroundUpdates)
                Text("The app saves your index. Closing the window keeps watching active; quitting stops it. Activity is sampled only while its panel is visible.").font(.caption).foregroundStyle(.secondary)
                Toggle("Open StorageWarden at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { loginError = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
                if let loginError { Text(loginError).foregroundStyle(.red).font(.caption) }
            }
            Section("Scanning") {
                Toggle("Include hidden files", isOn: $session.scanHiddenFiles)
                Stepper("Maximum depth: \(session.maxScanDepth)", value: $session.maxScanDepth, in: 20...240, step: 10)
                Text("Background refresh waits during Low Power Mode or high thermal pressure. Full rescans are manual. Package contents remain inspectable in Disk Map.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy & ownership") {
                Text("Free for life. MIT licensed. No accounts, ads, analytics, crash uploads, or app network requests.")
                Text("File metadata and cleanup history are stored only in ~/Library/Application Support/StorageWarden. Process readings are never saved. Links you choose to open use your browser.").font(.caption).foregroundStyle(.secondary)
                Button("Show First-Time Introduction") { introCompleted = false }
                Link("Source: Sjayeshkumar on GitHub", destination: URL(string: "https://github.com/Sjayeshkumar")!)
            }
        }.formStyle(.grouped).frame(width: 580, height: 600)
    }
}
