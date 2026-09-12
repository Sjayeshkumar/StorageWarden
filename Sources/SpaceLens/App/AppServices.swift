import AppKit
import CoreServices
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AppServices { static let shared = AppServices() }

@MainActor
public final class ScanStatus: ObservableObject {
    @Published public var progress = ScanProgress()
}

@MainActor
public final class AppSession: ObservableObject {
    public enum ScanState: String { case idle = "Ready", preparing = "Preparing", scanning = "Scanning", failed = "Failed", completed = "Completed" }
    @Published public private(set) var state: ScanState = .idle
    @Published public private(set) var volumes: [VolumeScanResult] = []
    @Published public private(set) var selectedVolumeID: UUID?
    @Published public var selectedSection: WorkspaceSection = .overview
    @Published public var selectedVisualizationMode = VisualizationMode(rawValue: UserDefaults.standard.string(forKey: "visualization") ?? "Sunburst") ?? .sunburst {
        didSet { UserDefaults.standard.set(selectedVisualizationMode.rawValue, forKey: "visualization") }
    }
    @Published public var selectedNodeIDs: Set<UUID> = []
    public let scanStatus = ScanStatus()
    public var scanProgress: ScanProgress { scanStatus.progress }
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastScanAt: Date?
    @Published public private(set) var accessibilityIssues: [ScanIssue] = []
    @Published public private(set) var trashHistory: [TrashOperation] = []
    @Published public var currentDeletionPreview: DeletionPreview?
    @Published public var isDeletionSheetPresented = false
    @Published public var deletionError: String?
    @Published public private(set) var isDeleting = false
    @Published public private(set) var isLoadingIndex = true
    @Published public private(set) var revision = UUID()
    @Published public private(set) var pendingChangeCount = 0
    @Published public private(set) var requiresFullRescan = false
    @Published public var backgroundUpdates = UserDefaults.standard.object(forKey: "backgroundUpdates") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(backgroundUpdates, forKey: "backgroundUpdates")
            if backgroundUpdates { startWatching(); scheduleRefresh() } else { watcher.stop(); refreshTask?.cancel(); refreshTask = nil }
        }
    }
    @Published public var scanHiddenFiles = UserDefaults.standard.object(forKey: "scanHiddenFiles") as? Bool ?? true {
        didSet { UserDefaults.standard.set(scanHiddenFiles, forKey: "scanHiddenFiles") }
    }
    @Published public var maxScanDepth = UserDefaults.standard.object(forKey: "maxScanDepth") as? Int ?? 80 {
        didSet { UserDefaults.standard.set(maxScanDepth, forKey: "maxScanDepth") }
    }
    @Published public var includePackagesAsFiles = false
    @Published public var revealFinderAfterDelete = false
    public let workspaceSections = WorkspaceSection.allWorkspaceSections
    private let catalog = AppCatalog.shared
    private let snapshotStore = StorageSnapshotStore.shared
    private let worker = IndexWorker()
    private let progressRelay = ScanProgressRelay()
    private let watcher = FolderWatcher()
    private var indexes: [UUID: StorageIndex] = [:]
    private var scanTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var dirtyPaths: Set<String> = []
    private var requestedRoots: [URL]?
    private var lastCheckpoint = Date.distantPast
    @Published private var folderPathByVolume: [UUID: String] = [:]

    public init() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            isLoadingIndex = false
            return
        }
        Task {
            await progressRelay.attach { [weak self] value in self?.scanStatus.progress = value }
            watcher.onChange = { [weak self] paths, dropped in self?.changed(paths, dropped: dropped) }
            if let saved = await snapshotStore.loadSnapshot() {
                let prepared = await worker.prepare(saved)
                install(prepared)
                state = .completed
                startWatching()
            }
            isLoadingIndex = false
            // Opening the app never starts a full scan. Onboarding offers the first scan.
        }
    }

    public var selectedVolume: VolumeScanResult? { volumes.first { $0.id == selectedVolumeID } }
    private var currentIndex: StorageIndex? { selectedVolumeID.flatMap { indexes[$0] } }
    public var currentFolderNode: ScanNode {
        guard let volume = selectedVolume else { return .placeholder }
        let path = folderPathByVolume[volume.id] ?? volume.rootNode.path
        return currentIndex?.byPath[path].flatMap { currentIndex?.byID[$0] } ?? volume.rootNode
    }
    public var selectedNodes: [ScanNode] {
        let candidates = selectedNodeIDs.compactMap { currentIndex?.byID[$0] }.sorted { $0.path.count < $1.path.count }
        var result: [ScanNode] = []
        for node in candidates where !result.contains(where: { node.path.hasPrefix($0.path + "/") }) { result.append(node) }
        return result
    }
    public var selectionSummary: SelectionSummary {
        var low: Int64 = 0, review: Int64 = 0, important: Int64 = 0, protected: Int64 = 0, total: Int64 = 0, allocated: Int64 = 0
        let nodes = selectedNodes
        for node in nodes {
            total += node.logicalSize; allocated += node.allocatedSize
            switch node.classification.cleanupRisk {
            case .safeToReview, .usuallyRecreatable: low += node.logicalSize
            case .reviewCarefully, .unknown: review += node.logicalSize
            case .importantData: important += node.logicalSize
            case .systemProtected: protected += node.logicalSize
            }
        }
        return SelectionSummary(count: nodes.count, totalLogicalSize: total, totalAllocatedSize: allocated, lowRiskLogical: low, reviewLogical: review, importantLogical: important, protectedLogical: protected)
    }
    public var canScan: Bool { scanTask == nil && !isLoadingIndex && !isDeleting }
    public var canDeleteSelection: Bool { !isDeleting && !selectedNodes.isEmpty && selectedNodes.allSatisfy(canDelete(node:)) }
    public var selectedIssues: [ScanIssue] { selectedVolume?.accessibilityIssues ?? [] }
    var categoryBuckets: [CategoryBucket] { currentIndex?.buckets ?? [] }
    var largestFolders: [ScanNode] { currentIndex?.largestFolders ?? [] }
    func sectionSize(_ section: WorkspaceSection) -> Int64 { currentIndex?.totals[section] ?? 0 }
    func sectionCount(_ section: WorkspaceSection) -> Int { currentIndex?.counts[section] ?? 0 }

    public func startScan() {
        guard canScan else { return }
        let roots = requestedRoots ?? (volumes.isEmpty ? [FileManager.default.homeDirectoryForCurrentUser, URL(fileURLWithPath: "/Applications")] : volumes.map { URL(fileURLWithPath: $0.volumeURL) })
        state = .preparing
        scanTask = Task(priority: .utility) { await runScan(roots: roots) }
    }
    public func startDeepScan() { startScan() }
    public func cancelScan() { scanTask?.cancel() }
    public func selectVolume(id: UUID) { selectedVolumeID = id; selectedSection = .storage; selectedNodeIDs.removeAll() }
    public func select(section: WorkspaceSection) {
        if section == .applications, let apps = volumes.first(where: { $0.volumeURL == "/Applications" }) { selectedVolumeID = apps.id }
        else if section.isCategory, selectedVolume?.volumeURL == "/Applications", let home = volumes.first(where: { $0.volumeURL == NSHomeDirectory() }) { selectedVolumeID = home.id }
        selectedSection = section
        if section != .review { selectedNodeIDs.removeAll() }
    }
    public func chooseFolder() {
        guard canScan else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Scan Folder"
        panel.message = "Scan once. StorageWarden saves the result on this Mac."
        if panel.runModal() == .OK, let url = panel.url { requestedRoots = [url]; startScan() }
    }
    public func explore(_ node: ScanNode) {
        if node.isDirectory { selectedSection = .storage; setCurrentFolder(node.path) }
        else { selectedNodeIDs = [node.id] }
    }
    public func setCurrentFolder(_ path: String) { guard let id = selectedVolumeID else { return }; folderPathByVolume[id] = path; selectedNodeIDs.removeAll() }
    public func openCurrentFolderInFinder() { NSWorkspace.shared.activateFileViewerSelecting([currentFolderNode.url]) }
    public func openNodeInFinder(_ node: ScanNode) { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
    public func node(with id: UUID) -> ScanNode? { currentIndex?.byID[id] }
    public func nodes(for section: WorkspaceSection, in volume: VolumeScanResult) -> [ScanNode] {
        if section == .storage { return currentFolderNode.children }
        return indexes[volume.id]?.sections[section] ?? []
    }
    public func canDelete(node: ScanNode) -> Bool {
        node.classification.removeAllowed && node.classification.importance != .critical && node.classification.cleanupRisk != .systemProtected && !volumes.contains { $0.volumeURL == node.path }
    }
    public func requestDeleteForSelection() {
        guard canDeleteSelection else { return }
        let nodes = selectedNodes
        currentDeletionPreview = DeletionPreview(title: "Move \(nodes.count) item(s) to Trash?", items: nodes, totalLogicalSize: nodes.reduce(0) { $0 + $1.logicalSize }, totalAllocatedSize: nodes.reduce(0) { $0 + $1.allocatedSize })
        deletionError = nil; isDeletionSheetPresented = true
    }
    public func deleteNode(_ node: ScanNode) { selectedNodeIDs = [node.id]; requestDeleteForSelection() }
    public func closeDeletionSheet() { isDeletionSheetPresented = false; deletionError = nil; currentDeletionPreview = nil }
    public func confirmDeletion() {
        guard !isDeleting, let preview = currentDeletionPreview, preview.items.allSatisfy(canDelete(node:)) else { return }
        isDeleting = true
        Task {
            let results = await TrashWorker().move(preview.items)
            trashHistory.insert(contentsOf: results, at: 0)
            if let failed = results.first(where: { !$0.success }) { deletionError = failed.error }
            trashHistory = Array(trashHistory.prefix(200))
            selectedNodeIDs.removeAll(); currentDeletionPreview = nil; isDeletionSheetPresented = false; isDeleting = false
            await save()
            changed(preview.items.map { $0.url.deletingLastPathComponent().path }, dropped: false)
            refreshChanges(persistImmediately: true)
        }
    }

    private func runScan(roots: [URL]) async {
        watcher.stop(); refreshTask?.cancel(); refreshTask = nil
        defer { scanTask = nil; startWatching(); scheduleRefresh() }
        errorMessage = nil; state = .scanning
        let scanner = StorageScanner(options: .init(includeHidden: scanHiddenFiles, maxDepth: maxScanDepth))
        do {
            // Commit each root separately so cancelling a later root retains completed work.
            for root in roots {
                let results = try await scanner.scan(volumes: [root], catalog: catalog, progress: progressRelay)
                try Task.checkCancellation()
                var merged = volumes.filter { $0.volumeURL != root.path }
                merged.append(contentsOf: results)
                let prepared = await worker.prepare(ScanSnapshot(generatedAt: Date(), volumeResults: merged, trashHistory: trashHistory))
                try Task.checkCancellation()
                install(prepared)
                await save()
            }
            dirtyPaths.removeAll(); pendingChangeCount = 0; requiresFullRescan = false
            state = .completed
        } catch is CancellationError { state = volumes.isEmpty ? .idle : .completed }
        catch { errorMessage = error.localizedDescription; state = .failed }
        requestedRoots = nil
    }

    private func install(_ prepared: IndexedSnapshot) {
        let previousPath = selectedVolume?.volumeURL
        indexes = prepared.indexes
        volumes = prepared.snapshot.volumeResults
        selectedVolumeID = volumes.first(where: { $0.volumeURL == previousPath })?.id ?? volumes.first?.id
        trashHistory = prepared.snapshot.trashHistory
        lastScanAt = prepared.snapshot.generatedAt
        accessibilityIssues = volumes.flatMap(\.accessibilityIssues)
        selectedNodeIDs.removeAll()
        revision = UUID()
    }
    private func save() async {
        let snapshot = ScanSnapshot(generatedAt: lastScanAt ?? Date(), volumeResults: volumes, trashHistory: trashHistory)
        if let message = await snapshotStore.persist(snapshot) { errorMessage = message }
        else { lastCheckpoint = Date() }
    }
    private func startWatching() {
        guard backgroundUpdates, !volumes.isEmpty else { return }
        watcher.start(paths: volumes.map(\.volumeURL))
    }
    private func changed(_ paths: [String], dropped: Bool) {
        requiresFullRescan = requiresFullRescan || dropped
        let own = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/StorageWarden").path
        for path in paths where path != own && !path.hasPrefix(own + "/") {
            guard let volume = volumes.first(where: { path == $0.volumeURL || path.hasPrefix($0.volumeURL + "/") }) else { continue }
            let index = indexes[volume.id]
            var folder = URL(fileURLWithPath: path)
            while folder.path != volume.volumeURL && index?.byPath[folder.path] == nil { folder.deleteLastPathComponent() }
            if let id = index?.byPath[folder.path], index?.byID[id]?.isDirectory == false { folder.deleteLastPathComponent() }
            dirtyPaths.insert(folder.path)
        }
        pendingChangeCount = dirtyPaths.count
        scheduleRefresh()
    }
    private func scheduleRefresh() {
        guard backgroundUpdates, refreshTask == nil, !dirtyPaths.isEmpty, !requiresFullRescan else { return }
        refreshTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) } catch { return }
            guard let self else { return }
            self.refreshTask = nil
            if ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical { self.scheduleRefresh(); return }
            self.refreshChanges()
        }
    }
    public func refreshChanges(persistImmediately: Bool = false) {
        guard canScan, !dirtyPaths.isEmpty, !requiresFullRescan else { scheduleRefresh(); return }
        var paths: [String] = []
        let allChanged = dirtyPaths
        for path in dirtyPaths.sorted(by: { $0.count < $1.count }) where !paths.contains(where: { path.hasPrefix($0 + "/") }) { paths.append(path) }
        dirtyPaths = dirtyPaths.filter { dirty in !paths.contains { dirty == $0 || dirty.hasPrefix($0 + "/") } }; pendingChangeCount = dirtyPaths.count
        state = .scanning
        scanTask = Task(priority: .utility) {
            defer { scanTask = nil; scheduleRefresh() }
            do {
                var updated = volumes
                for path in paths {
                    try Task.checkCancellation()
                    guard let index = updated.firstIndex(where: { path == $0.volumeURL || path.hasPrefix($0.volumeURL + "/") }) else { continue }
                    let url = URL(fileURLWithPath: path)
                    let scanner = StorageScanner(options: .init(includeHidden: scanHiddenFiles, maxDepth: maxScanDepth))
                    if FileManager.default.fileExists(atPath: path) {
                        let cache = indexes[updated[index].id]
                        let results = try await scanner.scan(volumes: [url], catalog: catalog, progress: progressRelay, cachedNodes: cache?.byID ?? [:], cachedPaths: cache?.byPath ?? [:], changedPaths: allChanged)
                        if let result = results.first { updated[index] = await worker.replace(in: updated[index], path: path, replacement: result.rootNode, issues: result.accessibilityIssues) }
                    } else if path == updated[index].volumeURL {
                        throw CocoaError(.fileReadNoSuchFile)
                    } else { updated[index] = await worker.replace(in: updated[index], path: path, replacement: nil, issues: []) }
                }
                let prepared = await worker.prepare(ScanSnapshot(generatedAt: Date(), volumeResults: updated, trashHistory: trashHistory))
                try Task.checkCancellation(); install(prepared); state = .completed
                // Avoid rewriting a million-record checkpoint for every burst of cache changes.
                if persistImmediately || Date().timeIntervalSince(lastCheckpoint) >= 900 { await save() }
            } catch {
                dirtyPaths.formUnion(paths); pendingChangeCount = dirtyPaths.count
                state = .completed
                if !(error is CancellationError) { errorMessage = error.localizedDescription }
            }
        }
    }
}

actor TrashWorker {
    func move(_ nodes: [ScanNode]) -> [TrashOperation] {
        nodes.map { node in
            do {
                let canonical = node.url.resolvingSymlinksInPath()
                guard canonical.path == node.path, !["/System", "/bin", "/sbin", "/usr", "/private"].contains(where: { canonical.path == $0 || canonical.path.hasPrefix($0 + "/") }) else { throw CocoaError(.fileWriteNoPermission) }
                try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                return TrashOperation(path: node.path, size: node.logicalSize, success: true)
            } catch { return TrashOperation(path: node.path, size: node.logicalSize, success: false, error: error.localizedDescription) }
        }
    }
}
public actor AppCatalog {
    public static let shared = AppCatalog()

    private var installedByAppPath: [String: String] = [:]
    private var displayByBundleID: [String: String] = [:]
    private var hasPreloaded = false

    public init() {}

    func snapshot() -> AppCatalogIndex {
        AppCatalogIndex(appPaths: installedByAppPath, bundleNames: displayByBundleID)
    }

    public func preloadInstalledApplications() async {
        guard !hasPreloaded else { return }
        defer { hasPreloaded = true }

        let searchPaths = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var pathMap: [String: String] = [:]
        var idMap: [String: String] = [:]

        for root in searchPaths {
            await ingest(root: root, pathMap: &pathMap, idMap: &idMap)
        }

        installedByAppPath = pathMap
        displayByBundleID = idMap
    }

    public func resolveApp(for path: String) async -> String? {
        let normalized = path.lowercased()

        if normalized.contains("/applications/") {
            if let match = installedByAppPath.first(where: { normalized.hasPrefix($0.key) || normalized.hasPrefix($0.key + "/") }) {
                return match.value
            }
        }

        let last = URL(fileURLWithPath: path).lastPathComponent
        if last.hasSuffix(".app") {
            let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return humanize(stem)
        }

        for (bundleID, display) in displayByBundleID where normalized.contains(bundleID.lowercased()) {
            return display
        }

        return nil
    }

    public func clearCache() {
        hasPreloaded = false
        installedByAppPath.removeAll()
        displayByBundleID.removeAll()
    }

    private func ingest(root: URL, pathMap: inout [String: String], idMap: inout [String: String]) async {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }

        for entry in entries where entry.pathExtension.lowercased() == "app" {
            let lower = entry.path.lowercased()
            pathMap[lower] = displayName(for: entry) ?? entry.deletingPathExtension().lastPathComponent

            if let id = Bundle(url: entry)?.bundleIdentifier?.lowercased() {
                idMap[id] = displayName(for: entry) ?? entry.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func displayName(for url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return name
        }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return nil
    }

    private func humanize(_ value: String) -> String {
        let clean = value.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return clean.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}

public enum FileIntelligence {
    private static let homePath = FileManager.default.homeDirectoryForCurrentUser.path.lowercased()
    public static func classify(
        path: String,
        isDirectory: Bool,
        isPackage: Bool,
        fileType: String,
        logicalSize: Int64,
        catalogAssociation: String?,
        uniformTypeIdentifier: String? = nil
    ) -> FileClassification {
        let normalized = normalized(path)
        let ext = fileType.lowercased()
        let uti = (uniformTypeIdentifier ?? "").lowercased()
        let owner = catalogAssociation

        if isSystemPath(normalized) {
            return FileClassification(
                category: .system,
                importance: .critical,
                cleanupRisk: .systemProtected,
                confidence: .high,
                explanation: "Core macOS system locations are required for system operation.",
                deletionConsequences: "Do not delete. Removing this item can make the system unstable or unbootable.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Reveal only. No cleanup action is available.",
                associatedApplication: "macOS"
            )
        }

        if isDirectory, isPackage, looksLikeAppBundle(normalized) {
            let appName = URL(fileURLWithPath: normalized).deletingPathExtension().lastPathComponent
            return FileClassification(
                category: .applicationBundle,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: .high,
                explanation: "This is an application bundle.",
                deletionConsequences: "Deleting it removes and disables the application from launch.",
                canBeRecreated: false,
                removeAllowed: true,
                defaultAction: "Quit the app, then review moving its bundle to Trash. Associated data is reviewed separately.",
                associatedApplication: appName
            )
        }

        if isArchive(ext) {
            return FileClassification(
                category: .archive,
                importance: .medium,
                cleanupRisk: owner == nil ? .reviewCarefully : .usuallyRecreatable,
                confidence: owner == nil ? .low : .medium,
                explanation: "Archive package. Useful for backup or distribution; not always safe to remove.",
                deletionConsequences: "Archive files may contain installers, installers, source packs, or backup images.",
                canBeRecreated: false,
                removeAllowed: true,
                defaultAction: "Remove only if you do not need this archive.",
                associatedApplication: owner
            )
        }

        if isMailPath(normalized) {
            return FileClassification(
                category: .applicationSupport,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: .high,
                explanation: "Mail database and local mailbox data for a user account.",
                deletionConsequences: "Local mail and state may be lost or require re-download.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Review via Mail app first.",
                associatedApplication: owner ?? "Mail"
            )
        }

        if isVideoOrMedia(ext, uti: uti, normalized: normalized, isDirectory: isDirectory) {
            return FileClassification(
                category: .media,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: .medium,
                explanation: "Likely user media content (video, audio, photo, or rendered artifact).",
                deletionConsequences: "Files may be user-created or project content and unrecoverable if deleted.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Remove only if you are absolutely sure this is disposable.",
                associatedApplication: owner
            )
        }

        if isCachePath(normalized) {
            let risk: CleanupSafety = owner == nil ? .reviewCarefully : .usuallyRecreatable
            let recAction = owner == nil ? "Do not cleanup: ownership is unclear." : "Usually safe to clear; app may repopulate it."
            return FileClassification(
                category: .appCache,
                importance: .low,
                cleanupRisk: risk,
                confidence: owner == nil ? .low : .medium,
                explanation: owner == nil ? "Cache-like path but owner not confidently identified." : "Application cache folder.",
                deletionConsequences: "The app may need time to rebuild local caches and may temporarily lose performance.",
                canBeRecreated: true,
                removeAllowed: owner != nil,
                defaultAction: recAction,
                associatedApplication: owner
            )
        }

        if isBrowserCachePath(normalized) {
            return FileClassification(
                category: .browserCache,
                importance: .low,
                cleanupRisk: owner == nil ? .reviewCarefully : .usuallyRecreatable,
                confidence: owner == nil ? .low : .high,
                explanation: "Browser cache and network material for faster online navigation.",
                deletionConsequences: "The browser may re-download frequently used images and website resources.",
                canBeRecreated: true,
                removeAllowed: owner != nil,
                defaultAction: "Usually safe to clear after closing the browser.",
                associatedApplication: owner ?? "Browser"
            )
        }

        if isDatabasePath(normalized, ext: ext) {
            return FileClassification(
                category: .databases,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: .medium,
                explanation: "Structured database file used for local state or app history.",
                deletionConsequences: "App data and indexes can be lost or require rebuild.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Remove only after backing up or through application controls.",
                associatedApplication: owner
            )
        }

        if isDownloadPath(normalized) {
            return FileClassification(
                category: .downloads,
                importance: .medium,
                cleanupRisk: .reviewCarefully,
                confidence: owner == nil ? .low : .medium,
                explanation: "User download area, can contain installers and useful artifacts.",
                deletionConsequences: "Files may be needed for installers, manuals, datasets, or media.",
                canBeRecreated: false,
                removeAllowed: true,
                defaultAction: "Clear installer archives quickly if known temporary.",
                associatedApplication: owner
            )
        }

        if isDocumentsPath(normalized) {
            return FileClassification(
                category: .documents,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: owner == nil ? .low : .medium,
                explanation: "Likely user documents or project material.",
                deletionConsequences: "Removing can lose user-created work with no automatic backup.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Do not delete unless you are certain.",
                associatedApplication: owner
            )
        }

        if isDeveloperArtifact(normalized) {
            return FileClassification(
                category: .developer,
                importance: .medium,
                cleanupRisk: .usuallyRecreatable,
                confidence: owner == nil ? .low : .medium,
                explanation: "Developer artifact that is often regenerated from builds.",
                deletionConsequences: "Builds and temporary indexes may need recreation.",
                canBeRecreated: true,
                removeAllowed: true,
                defaultAction: "Good cleanup candidate when builds are currently stopped.",
                associatedApplication: owner ?? "Xcode"
            )
        }

        if isVirtualMachinePath(normalized) {
            return FileClassification(
                category: .virtualMachine,
                importance: .high,
                cleanupRisk: .importantData,
                confidence: .high,
                explanation: "Virtual machine image with complete environment.",
                deletionConsequences: "All guest systems and project state stored there are lost.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Never delete unless you have another complete backup.",
                associatedApplication: owner
            )
        }

        if isLogPath(normalized) {
            return FileClassification(
                category: .logs,
                importance: .low,
                cleanupRisk: .usuallyRecreatable,
                confidence: owner == nil ? .low : .medium,
                explanation: "Diagnostic or crash log data used for troubleshooting.",
                deletionConsequences: "You lose historical diagnostic trails.",
                canBeRecreated: true,
                removeAllowed: true,
                defaultAction: "Usually safe to clear if no active diagnostics are needed.",
                associatedApplication: owner
            )
        }

        if let known = owner, !known.isEmpty {
            return FileClassification(
                category: inferredCategory(normalized),
                importance: inferredImportance(normalized, hasOwner: true),
                cleanupRisk: .reviewCarefully,
                confidence: .medium,
                explanation: "Path aligns with known installed app storage or data footprint.",
                deletionConsequences: "Can affect data and app behavior depending on the subfolder.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Review carefully before cleanup.",
                associatedApplication: known
            )
        }

        return FileClassification(
            category: inferredCategory(normalized),
            importance: inferredImportance(normalized, hasOwner: false),
            cleanupRisk: .unknown,
            confidence: .low,
            explanation: "Purpose could not be confidently determined.",
            deletionConsequences: "Unknown cleanup risk. Removal may have unintended effects.",
            canBeRecreated: false,
            removeAllowed: false,
            defaultAction: "Reveal in Finder and inspect before any cleanup.",
            associatedApplication: nil
        )
    }

    private static func normalized(_ path: String) -> String {
        path.replacingOccurrences(of: "\\\\", with: "/").lowercased()
    }

    private static func isSystemPath(_ path: String) -> Bool {
        let protected: [String] = ["/system", "/bin", "/sbin", "/usr", "/private/var/vm", "/cores", "/var/db/dyld", "/private/preboot"]
        return protected.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func looksLikeAppBundle(_ path: String) -> Bool {
        path.hasSuffix(".app") || path.contains(".app/")
    }

    private static func isArchive(_ ext: String) -> Bool {
        ["zip", "dmg", "pkg", "7z", "xz", "bz2", "rar", "tar", "gz", "tgz", "iso", "ipsw", "jar", "xz", "xz", "mpkg"].contains(ext)
    }

    private static func isMailPath(_ path: String) -> Bool {
        path.contains("/mail/") || path.contains("/mail.app") || path.contains("/library/mail")
    }

    private static func isDownloadPath(_ path: String) -> Bool {
        path.contains("/downloads")
    }

    private static func isDocumentsPath(_ path: String) -> Bool {
        path.contains("/documents")
    }

    private static func isDeveloperArtifact(_ path: String) -> Bool {
        let root = homePath
        let markers = [root + "/library/developer/xcode/deriveddata", root + "/library/caches/com.apple.dt.xcode"]
        return markers.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func isVirtualMachinePath(_ path: String) -> Bool {
        path.contains(".vmware") || path.contains(".vmdk") || path.contains(".qcow") || path.contains(".vdi")
    }

    private static func isDatabasePath(_ path: String, ext: String) -> Bool {
        ["db", "sqlite", "sqlite3", "realm", "ibd", "mdb", "sql"].contains(ext)
    }

    private static func isLogPath(_ path: String) -> Bool {
        path.contains("/logs/") || path.hasSuffix(".log") || path.contains("/diagnosticreports")
    }

    private static func isCachePath(_ path: String) -> Bool {
        let normalized = path.replacingOccurrences(of: "//", with: "/")
        return normalized.contains("/library/caches/") || normalized.contains("/tmp/") || normalized.hasSuffix("/tmp")
    }

    private static func isBrowserCachePath(_ path: String) -> Bool {
        let browserCaches = ["/library/caches/com.apple.safari", "/library/caches/com.google.chrome", "/library/caches/com.brave", "/library/caches/com.microsoft", "/library/caches/com.mozilla.firefox", "/library/caches/com.oper", "/library/caches/org.mozilla"]
        return browserCaches.contains { path.contains($0) }
    }

    private static func isVideoOrMedia(_ ext: String, uti: String, normalized: String, isDirectory: Bool) -> Bool {
        if isDirectory { return false }
        let mediaExt = ["mp4", "mov", "mkv", "avi", "m4v", "m4a", "aac", "heic", "png", "jpg", "jpeg", "raw", "dng", "gif", "tiff", "webm", "flac", "wav"]
        if mediaExt.contains(ext) { return true }
        if uti.contains("image") || uti.contains("video") || uti.contains("audio") {
            return true
        }
        return normalized.contains("/pictures") || normalized.contains("/movies") || normalized.contains("/movies")
    }

    private static func inferredCategory(_ path: String) -> StorageCategory {
        if isCachePath(path) { return .appCache }
        if isMailPath(path) { return .applicationSupport }
        if isDownloadPath(path) { return .downloads }
        if isDocumentsPath(path) { return .documents }
        if isVideoOrMedia("", uti: "", normalized: path, isDirectory: false) { return .media }
        if isVirtualMachinePath(path) { return .virtualMachine }
        if path.contains("/library/application support") { return .applicationSupport }
        return .unknown
    }

    private static func inferredImportance(_ path: String, hasOwner: Bool) -> ImportanceLevel {
        if isCachePath(path) {
            return .low
        }
        if path.contains("/library/application support/") || path.contains("/library/containers/") || path.contains("/library/caches/") {
            return hasOwner ? .medium : .high
        }
        if isDocumentsPath(path) || path.contains("/desktop") || isDownloadPath(path) {
            return .high
        }
        if isVideoOrMedia("", uti: "", normalized: path, isDirectory: false) {
            return .high
        }
        return hasOwner ? .medium : .unknown
    }
}


public actor StorageSnapshotStore {
    public static let shared = StorageSnapshotStore()
    private let customDirectory: URL?
    public init(directory: URL? = nil) { customDirectory = directory }
    private var directory: URL { customDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/StorageWarden", isDirectory: true) }
    private var path: URL { directory.appendingPathComponent("index.plist") }

    public func loadSnapshot() async -> ScanSnapshot? {
        if let data = try? Data(contentsOf: path, options: .mappedIfSafe), let value = try? PropertyListDecoder().decode(ScanSnapshot.self, from: data) { return value }
        guard customDirectory == nil else { return nil }
        // Import the previous local index once; it is never discarded simply on launch.
        let legacy = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/SpaceLens/scan_snapshot_v2.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: legacy, options: .mappedIfSafe), let value = try? decoder.decode(ScanSnapshot.self, from: data) {
            _ = await persist(value)
            return value
        }
        return nil
    }
    public func persist(_ snapshot: ScanSnapshot) async -> String? {
        do {
            let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try data.write(to: path, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
            return nil
        } catch { return "The local index could not be saved: \(error.localizedDescription)" }
    }
    public func saveSnapshot(_ snapshot: ScanSnapshot) async { _ = await persist(snapshot) }
}
