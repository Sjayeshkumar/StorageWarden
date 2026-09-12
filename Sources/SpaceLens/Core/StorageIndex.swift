import Foundation

/// Immutable lookup tables are prepared on a worker actor, never in a SwiftUI body.
struct StorageIndex: Sendable {
    var byID: [UUID: ScanNode] = [:]
    var byPath: [String: UUID] = [:]
    var sections: [WorkspaceSection: [ScanNode]] = [:]
    var buckets: [CategoryBucket] = []
    var largestFolders: [ScanNode] = []
    var totals: [WorkspaceSection: Int64] = [:]
    var counts: [WorkspaceSection: Int] = [:]

    init(root: ScanNode) {
        var categories: [StorageCategory: (Int64, Int)] = [:]
        let old = Date().addingTimeInterval(-180 * 86400)
        let recent = Date().addingTimeInterval(-60 * 86400)
        let video: Set<String> = ["mp4", "mov", "mkv", "avi", "m4v", "webm"]
        let audio: Set<String> = ["mp3", "m4a", "aac", "flac", "wav", "aiff"]
        let pictures: Set<String> = ["heic", "png", "jpg", "jpeg", "raw", "dng", "gif", "tiff"]
        func visit(_ node: ScanNode, parentCategory: StorageCategory?, parentOwner: String?) {
            byID[node.id] = node
            byPath[node.path] = node.id
            let category = node.classification.category
            if category != parentCategory {
                for section in WorkspaceSection.categorySections where section.category == category && ![.movies, .music, .pictures].contains(section) {
                    sections[section, default: []].append(node)
                }
            }
            if let owner = node.classification.associatedApplication, owner != parentOwner {
                sections[.appStorage, default: []].append(node)
            }
            if !node.isDirectory {
                let value = categories[category, default: (0, 0)]
                categories[category] = (value.0 + node.logicalSize, value.1 + 1)
                if node.logicalSize > 0 { sections[.largestFiles, default: []].append(node) }
                if let modified = node.modifiedAt, modified < old { sections[.oldFiles, default: []].append(node) }
                if let created = node.createdAt, created > recent { sections[.recentlyAdded, default: []].append(node) }
                if video.contains(node.fileType) { sections[.movies, default: []].append(node) }
                if audio.contains(node.fileType) { sections[.music, default: []].append(node) }
                if pictures.contains(node.fileType) { sections[.pictures, default: []].append(node) }
            }
            for child in node.children { visit(child, parentCategory: category, parentOwner: node.classification.associatedApplication) }
        }
        visit(root, parentCategory: nil, parentOwner: nil)
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        if let id = byPath[downloads], let folder = byID[id] { sections[.downloads] = folder.children }
        // Candidates remain explicitly unverified. Limit analysis to files at least 1 MB.
        let candidates = (sections[.largestFiles] ?? []).filter { $0.logicalSize >= 1_000_000 }
        let groups = Dictionary(grouping: candidates) { "\($0.logicalSize):\($0.fileType)" }
        sections[.duplicateCandidates] = groups.values.filter { $0.count > 1 }.flatMap { $0 }
        for key in Array(sections.keys) {
            sections[key]?.sort { $0.logicalSize > $1.logicalSize }
            totals[key] = sections[key]!.reduce(0) { $0 + $1.logicalSize }
            counts[key] = sections[key]!.count
        }
        buckets = categories.map { CategoryBucket(category: $0.key, size: $0.value.0, itemCount: $0.value.1) }.sorted { $0.size > $1.size }
        largestFolders = Array(root.children.filter(\.isDirectory).sorted { $0.logicalSize > $1.logicalSize }.prefix(6))
    }
}

struct IndexedSnapshot: Sendable {
    let snapshot: ScanSnapshot
    let indexes: [UUID: StorageIndex]
}

actor IndexWorker {
    func prepare(_ snapshot: ScanSnapshot) -> IndexedSnapshot {
        IndexedSnapshot(snapshot: snapshot, indexes: Dictionary(uniqueKeysWithValues: snapshot.volumeResults.map { ($0.id, StorageIndex(root: $0.rootNode)) }))
    }

    func query(_ nodes: [ScanNode], text: String, order: [KeyPathComparator<ScanNode>]) -> [ScanNode] {
        nodes.filter { text.isEmpty || $0.displayName.localizedCaseInsensitiveContains(text) || $0.path.localizedCaseInsensitiveContains(text) || $0.classification.associatedApplication?.localizedCaseInsensitiveContains(text) == true }.sorted(using: order)
    }

    func replace(in volume: VolumeScanResult, path: String, replacement: ScanNode?, issues: [ScanIssue]) -> VolumeScanResult {
        func replacing(_ node: ScanNode) -> ScanNode? {
            if node.path == path { return replacement }
            guard path.hasPrefix(node.path == "/" ? "/" : node.path + "/") else { return node }
            var children = node.children.compactMap { replacing($0) }
            if !node.children.contains(where: { $0.path == path }), URL(fileURLWithPath: path).deletingLastPathComponent().path == node.path, let replacement {
                children.append(replacement)
            }
            return ScanNode(id: node.id, name: node.name, path: node.path, isDirectory: node.isDirectory, logicalSize: children.reduce(0) { $0 + $1.logicalSize }, allocatedSize: children.reduce(0) { $0 + $1.allocatedSize }, fileType: node.fileType, itemCount: children.count, modifiedAt: node.modifiedAt, createdAt: node.createdAt, lastOpenedAt: node.lastOpenedAt, classification: node.classification, children: children)
        }
        let root = replacing(volume.rootNode) ?? volume.rootNode
        let capacityValues = try? root.url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let capacity = capacityValues.map { values in
            let total = Int64(values.volumeTotalCapacity ?? 0), available = Int64(values.volumeAvailableCapacity ?? 0)
            return VolumeCapacity(total: total, available: available, used: max(0, total - available))
        } ?? volume.capacity
        return VolumeScanResult(id: volume.id, volumeName: volume.volumeName, volumeURL: volume.volumeURL, scanStartedAt: volume.scanStartedAt, scanCompletedAt: Date(), rootNode: root, summary: [root].totals(), accessibilityIssues: volume.accessibilityIssues.filter { $0.path != path && !$0.path.hasPrefix(path + "/") } + issues, capacity: capacity)
    }
}

struct AppCatalogIndex: Sendable {
    let appPaths: [String: String]
    let bundleNames: [String: String]
    func resolve(_ path: String) -> String? {
        let components = path.lowercased().split(separator: "/")
        // Look up exact path components, not every installed app for every file.
        for component in components {
            if let name = bundleNames[String(component)] { return name }
        }
        if let index = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let bundlePath = "/" + components[...index].joined(separator: "/")
            return appPaths[bundlePath]
        }
        return nil
    }
}

extension IndexWorker {
    func distribution(_ nodes: [ScanNode]) -> [SizeDistributionBucket] { nodes.sizeDistributionBuckets() }
}
