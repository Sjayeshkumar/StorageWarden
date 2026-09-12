import AppKit
import SwiftUI

struct AppWorkspaceView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showInspector = false
    @State private var showIssues = false
    @State private var categoriesExpanded = false
    private var busy: Bool { session.state == .scanning || session.state == .preparing }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.hexagongrid.fill").font(.title).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("StorageWarden").font(.headline)
                        Text("Make room for what matters").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(18)
                List {
                    Section("Explore") {
                        navigationRow(.overview, title: "Overview")
                        navigationRow(.storage, title: "Disk Map")
                        navigationRow(.largestFiles, title: "Large Files")
                        navigationRow(.applications, title: "Applications")
                        navigationRow(.appStorage, title: "App Data")
                    }
                    Section("Make space") {
                        navigationRow(.review, title: "Cleanup")
                        navigationRow(.downloads, title: "Downloads")
                        navigationRow(.caches, title: "App Caches")
                        navigationRow(.developer, title: "Build Artifacts")
                        navigationRow(.oldFiles, title: "Old Files")
                    }
                    DisclosureGroup("More categories", isExpanded: $categoriesExpanded) {
                        ForEach([WorkspaceSection.documents, .movies, .music, .pictures, .archives, .applicationData, .other, .duplicateCandidates, .recentlyAdded]) { section in
                            navigationRow(section, title: section.displayTitle)
                        }
                    }
                    Section("Locations") {
                        ForEach(session.volumes) { volume in
                            Button { session.selectVolume(id: volume.id) } label: {
                                Label(volume.volumeURL == NSHomeDirectory() ? "Home Folder" : volume.volumeName, systemImage: "externaldrive")
                                    .lineLimit(1)
                            }.buttonStyle(.plain)
                        }
                        Button { session.chooseFolder() } label: { Label("Scan a folder…", systemImage: "plus.circle") }
                            .buttonStyle(.plain).disabled(busy)
                    }
                    navigationRow(.trashHistory, title: "Trash History")
                }.listStyle(.sidebar)
                if let volume = session.selectedVolume {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("Disk capacity"); Spacer(); Text("\(Int(volume.capacity.capacityUsedFraction * 100))% used") }
                            .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: volume.capacity.capacityUsedFraction).tint(.teal)
                        Text("\(volume.capacity.available.asStorageSize) available").font(.caption.weight(.medium))
                    }.padding(18)
                }
                SettingsLink { Label("Settings", systemImage: "gearshape") }.buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 16)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if busy { scanBanner }
                if session.isLoadingIndex {
                    ProgressView("Opening your saved index…").padding()
                }
                if session.requiresFullRescan {
                    Label("Some change events were missed. Rescan to reconcile this saved index.", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90").font(.caption).padding(10)
                } else if session.pendingChangeCount > 0 {
                    HStack {
                        Text("\(session.pendingChangeCount) changed folders waiting for a background refresh").font(.caption)
                        Spacer()
                        Button("Refresh Now") { session.refreshChanges() }.disabled(!session.canScan)
                    }.padding(10)
                }
                if let volume = session.selectedVolume {
                    content(volume)
                } else {
                    welcome
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(session.selectedSection == .storage ? "Disk Map" : session.selectedSection == .review ? "Cleanup" : session.selectedSection.displayTitle)
            .inspector(isPresented: $showInspector) {
                if let volume = session.selectedVolume {
                    InspectorView(volume: volume).inspectorColumnWidth(min: 280, ideal: 310, max: 350)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !session.selectedIssues.isEmpty {
                    Button { showIssues = true } label: { Label("\(session.selectedIssues.count) skipped", systemImage: "lock.shield") }
                        .help("Review locations that could not be measured")
                }
                Button { session.chooseFolder() } label: { Label("Scan Folder", systemImage: "folder.badge.plus") }.disabled(busy)
                Button { busy ? session.cancelScan() : session.startScan() } label: {
                    Label(busy ? "Stop Scan" : "Rescan", systemImage: busy ? "stop.circle" : "arrow.clockwise")
                }
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
        .sheet(isPresented: $session.isDeletionSheetPresented) { DeletionReviewSheet().environmentObject(session) }
        .sheet(isPresented: $showIssues) { issuesSheet }
        .alert("Cleanup could not finish", isPresented: Binding(get: { session.deletionError != nil && !session.isDeletionSheetPresented }, set: { if !$0 { session.deletionError = nil } })) {
            Button("OK") { session.deletionError = nil }
        } message: { Text(session.deletionError ?? "") }
        .onChange(of: session.selectedNodeIDs) { _, ids in
            if !ids.isEmpty { showInspector = true }
        }
    }

    private func navigationRow(_ section: WorkspaceSection, title: String) -> some View {
        Button { session.select(section: section) } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon).frame(width: 18).foregroundStyle(session.selectedSection == section ? Color.teal : Color.secondary)
                Text(title).font(.system(size: 13, weight: session.selectedSection == section ? .semibold : .regular))
                Spacer(minLength: 0)
            }.padding(.vertical, 7).padding(.horizontal, 9)
                .background(session.selectedSection == section ? Color.teal.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder private func content(_ volume: VolumeScanResult) -> some View {
        switch session.selectedSection {
        case .overview: OverviewScreen(volume: volume)
        case .review: CleanupDashboard(volume: volume)
        case .trashHistory:
            if session.trashHistory.isEmpty {
                ContentUnavailableView("Your cleanup history", systemImage: "trash", description: Text("Items you move to Trash with SpaceLens will appear here."))
            } else {
                List(session.trashHistory) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(URL(fileURLWithPath: item.path).lastPathComponent).fontWeight(.medium)
                            Text(item.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Text(item.error ?? item.timestamp.formatted()).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.size.asStorageSize).monospacedDigit()
                        Text(item.success ? "Moved to Trash" : "Failed").foregroundStyle(item.success ? .secondary : Color.red)
                    }.padding(.vertical, 6)
                }
            }
        default:
            StorageBrowserView(volume: volume, section: session.selectedSection, rootNode: session.currentFolderNode, nodes: session.nodes(for: session.selectedSection, in: volume))
                .id(session.selectedSection)
        }
    }

    private var scanBanner: some View {
        ScanBanner(status: session.scanStatus)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 64)).foregroundStyle(.teal.gradient)
            Text(busy ? "Getting to know your storage." : "A clearer view of your Mac.")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(busy ? "Your first scan builds a map of your files. You can follow its progress above." : "See what takes up space, understand unfamiliar files, and review what you no longer need.")
                .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = session.errorMessage { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Scan Home Folder") { session.startScan() }.buttonStyle(.borderedProminent).disabled(!session.canScan)
                Button("Choose a folder") { session.chooseFolder() }.disabled(!session.canScan)
            }.controlSize(.large)
            Label("Nothing is removed without your review.", systemImage: "checkmark.shield").foregroundStyle(.secondary)
            Spacer()
        }.padding(50).frame(maxWidth: 730, maxHeight: .infinity, alignment: .leading)
    }

    private var issuesSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan coverage").font(.title2.bold())
            Text("These locations were skipped or could not be read. Their contents are not included in the scan totals.").foregroundStyle(.secondary)
            List(session.selectedIssues) { issue in
                VStack(alignment: .leading, spacing: 5) {
                    Text(issue.path).textSelection(.enabled)
                    Text(issue.message).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            HStack {
                Button("Full Disk Access Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
                Spacer()
                Button("Done") { showIssues = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 640, height: 480)
    }
}

private struct ScanBanner: View {
    @ObservedObject var status: ScanStatus
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                Text("Indexing in background · \(status.progress.scannedItems.formatted()) items").font(.callout.weight(.medium))
                Text(status.progress.currentPath).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("Low-impact scan").font(.caption).foregroundStyle(.secondary)
        }.padding(14).background(Color.teal.opacity(0.07))
    }
}
