import AppKit
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("introCompleted") private var completed = false
    @State private var page = 0
    private let titles = ["Your Mac. Your space. Your rules.", "Scan once. Stay informed.", "A guardian, not a gatekeeper."]
    private let symbols = ["shield.lefthalf.filled", "folder.badge.gearshape", "hand.raised.fill"]
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Text("STORAGEWARDEN").font(.caption.weight(.bold)).tracking(2); Spacer(); Text("\(page + 1) / 3").foregroundStyle(.secondary) }
            Image(systemName: symbols[page]).font(.system(size: 62)).foregroundStyle(.teal.gradient).padding(.top, 8)
            Text(titles[page]).font(.system(size: 32, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            Group {
                switch page {
                case 0:
                    Text("A free, open-source view of your storage and your Mac's activity. No accounts, subscriptions, ads, analytics, or data uploads.")
                    Label("Free for life. Source available under the MIT license.", systemImage: "lock.open")
                case 1:
                    Text("Your index stays on this Mac and reopens without another full scan. Close the window and StorageWarden stays available in the menu bar.")
                    Toggle("Refresh changed folders in the background", isOn: $session.backgroundUpdates)
                    Text("Changes are batched every two minutes. Automatic refresh pauses in Low Power Mode or under thermal pressure. Quit the app to stop watching.").font(.caption)
                default:
                    Text("Every removal needs your review. System files are protected. Scans work with your existing permissions; Full Disk Access is optional.")
                    Button("Open Full Disk Access Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
                    Text("The local index stores file paths, sizes, dates, and cleanup history. Activity readings stay in memory only. Nothing is sent to us.").font(.caption)
                }
            }.foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                if page > 0 { Button("Back") { page -= 1 } }
                Spacer()
                if page < 2 { Button("Continue") { page += 1 }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
                else {
                    Button("Explore First") { completed = true }
                    Button("Choose First Folder") { completed = true; session.chooseFolder() }.buttonStyle(.borderedProminent).disabled(!session.canScan)
                }
            }.controlSize(.large)
        }.padding(36).frame(width: 570, height: 530).interactiveDismissDisabled()
    }
}
