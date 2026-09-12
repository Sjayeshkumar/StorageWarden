import AppKit
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("introCompleted") private var completed = false
    @State private var page = 0
    private let titles = ["Your files stay yours.", "Pick up where you left off.", "You choose what goes."]
    private let symbols = ["shield.lefthalf.filled", "folder.badge.gearshape", "hand.raised.fill"]
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Text("STORAGEWARDEN").font(.caption.weight(.bold)).tracking(2); Spacer(); Text("\(page + 1) / 3").foregroundStyle(.secondary) }
            Image(systemName: symbols[page]).font(.system(size: 62)).foregroundStyle(.teal.gradient).padding(.top, 8)
            Text(titles[page]).font(.system(size: 32, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            Group {
                switch page {
                case 0:
                    Text("See what takes up space and which processes are busy. StorageWarden works on your Mac. It does not upload your files, scan results, or activity. No accounts, ads, or tracking.")
                    Label("Free for life. Source available under the MIT license.", systemImage: "lock.open")
                case 1:
                    Text("Your last scan is saved on your Mac, so you do not have to start over every time. Close the window to keep StorageWarden in the menu bar. Quit the app to stop it.")
                    Toggle("Refresh changed folders in the background", isOn: $session.backgroundUpdates)
                    Text("While running, the app updates changed folders about every two minutes. Updates pause when your Mac needs to save power or cool down. Changes made while the app is quit need a new scan.").font(.caption)
                default:
                    Text("Nothing is removed automatically. Review your choices before moving files to Trash. Start with a folder you choose. Full Disk Access is optional if you want to scan more locations.")
                    Button("Open Full Disk Access Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
                    Text("Saved scans contain names, locations, sizes, dates, and cleanup history, not copies of your files. Activity readings are not saved. Nothing is sent to us. Website links open separately in your browser.").font(.caption)
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
