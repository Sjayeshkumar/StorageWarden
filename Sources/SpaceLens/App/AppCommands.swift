import AppKit
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var session: AppSession
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Activity") {
            Button("Show Activity Monitor") { openWindow(id: "activity") }
                .keyboardShortcut("m", modifiers: [.command, .option])
        }
        CommandGroup(after: .appInfo) {
            Button("Rescan") {
                session.startScan()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Cancel Scan") {
                session.cancelScan()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(session.state != .scanning)
        }

        CommandGroup(after: .newItem) {
            Button("Review Selected for Trash…") {
                session.requestDeleteForSelection()
            }
            .disabled(session.selectedNodes.isEmpty)
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Show Application Support Folder") {
                let url = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/StorageWarden", isDirectory: true)
                if !FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}
