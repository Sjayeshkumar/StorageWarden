import SwiftUI

@main
struct StorageWardenApp: App {
    @StateObject private var session = AppSession()
    @AppStorage("introCompleted") private var introCompleted = false
    @AppStorage("showMenuBarMonitor") private var showMonitor = true
    var body: some Scene {
        WindowGroup("StorageWarden", id: "main") {
            AppWorkspaceView().environmentObject(session)
                .frame(minWidth: 980, minHeight: 660).tint(.teal)
                .sheet(isPresented: Binding(get: { !introCompleted }, set: { if !$0 { introCompleted = true } })) {
                    WelcomeView().environmentObject(session)
                }
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1200, height: 800)
        .commands { AppCommands(session: session) }
        Settings { SettingsSceneView(session: session) }
        Window("Activity Monitor", id: "activity") {
            ActivityPanel().environmentObject(session)
        }.windowResizability(.contentSize)
        MenuBarExtra("StorageWarden Activity", systemImage: "shield.lefthalf.filled", isInserted: $showMonitor) {
            ActivityPanel().environmentObject(session)
        }.menuBarExtraStyle(.window)
    }
}
