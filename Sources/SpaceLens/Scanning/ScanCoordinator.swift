import Foundation
import os

public actor ScanProgressRelay {
    private var reporter: (@MainActor (ScanProgress) -> Void)?
    private var lastPublished = Date.distantPast

    public init() {}

    public func attach(_ reporter: (@MainActor (ScanProgress) -> Void)?) {
        self.reporter = reporter
    }

    public func publish(_ progress: ScanProgress) {
        guard Date().timeIntervalSince(lastPublished) > 0.5 || progress.phase != "Scanning" else { return }
        lastPublished = Date()
        let output = reporter
        Task { @MainActor in
            output?(progress)
        }
    }
}

public struct ScanRequestOptions: Codable, Sendable {
    public let includeHidden: Bool
    public let maxDepth: Int
    public let includePackagesAsFiles: Bool
    public let scanMode: ScanMode

    public init(includeHidden: Bool = false, maxDepth: Int = 80, includePackagesAsFiles: Bool = false, scanMode: ScanMode = .standard) {
        self.includeHidden = includeHidden
        self.maxDepth = maxDepth
        self.includePackagesAsFiles = includePackagesAsFiles
        self.scanMode = scanMode
    }
}

public actor StorageScanner {
    private let logger = Logger(subsystem: "com.spacelens.storage", category: "scanner")
    private let fm = FileManager.default
    private let options: ScanRequestOptions

    public init(options: ScanRequestOptions = .init()) {
        self.options = options
    }

    public func scan(volumes urls: [URL], catalog: AppCatalog, progress: ScanProgressRelay, cachedNodes: [UUID: ScanNode] = [:], cachedPaths: [String: UUID] = [:], changedPaths: Set<String> = []) async throws -> [VolumeScanResult] {
        let roots = sanitizeRoots(urls)
        guard !roots.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
        let scanRoots = roots

        await progress.publish(ScanProgress(phase: "Preparing", currentPath: "Loading app metadata"))
        await catalog.preloadInstalledApplications()
        let ownership = await catalog.snapshot()

        var results: [VolumeScanResult] = []
        for (index, volumeURL) in scanRoots.enumerated() {
            try Task.checkCancellation()

            let volumeName = volumeURL.lastPathComponent.isEmpty ? volumeURL.path : volumeURL.lastPathComponent
            await progress.publish(ScanProgress(phase: "Scanning", scannedItems: index, foldersVisited: 0, filesVisited: 0, currentPath: "Analyzing \(volumeName)"))

            var folderCount = 0
            var fileCount = 0
            var scannedNodeCount = 0
            var issues: [ScanIssue] = []
            let started = Date()

            let root = try await scanNode(
                at: volumeURL,
                depth: 0,
                options: options,
                ownership: ownership,
                cachedNodes: cachedNodes,
                cachedPaths: cachedPaths,
                changedPaths: changedPaths,
                issues: &issues,
                foldersVisited: &folderCount,
                filesVisited: &fileCount,
                scannedNodeCount: &scannedNodeCount,
                progress: progress
            )

            let capacity = await readCapacity(for: volumeURL)

            results.append(
                VolumeScanResult(
                    volumeName: volumeName,
                    volumeURL: volumeURL.path,
                    scanStartedAt: started,
                    scanCompletedAt: Date(),
                    rootNode: root,
                    summary: [root].totals(),
                    accessibilityIssues: issues,
                    capacity: capacity
                )
            )

            if index + 1 < scanRoots.count {
                await progress.publish(ScanProgress(phase: "Next", scannedItems: 0, foldersVisited: 0, filesVisited: 0, currentPath: "Moving to next volume"))
            }
        }

        await progress.publish(ScanProgress(phase: "Done", scannedItems: results.reduce(0, { $0 + $1.summary.itemCount }), currentPath: "Ready"))
        return results
    }

    private func sanitizeRoots(_ urls: [URL]) -> [URL] {
        var normalized: [URL] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else {
                continue
            }
            if !normalized.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path }) {
                normalized.append(url.standardizedFileURL)
            }
        }
        return normalized
    }

    private func readCapacity(for url: URL) async -> VolumeCapacity {
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) else {
            return VolumeCapacity()
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        let used = max(0, total - available)
        return VolumeCapacity(total: total, available: available, used: used)
    }

    private func issueKind(for error: Error) -> ScanIssueKind {
        let ns = error as NSError
        switch ns.code {
        case NSFileReadNoPermissionError, NSFileReadNoSuchFileError, CocoaError.fileReadNoPermission.rawValue:
            return .protectedArea
        default:
            return .transientError
        }
    }

    private func scanNode(
        at url: URL,
        depth: Int,
        options: ScanRequestOptions,
        ownership: AppCatalogIndex,
        cachedNodes: [UUID: ScanNode],
        cachedPaths: [String: UUID],
        changedPaths: Set<String>,
        issues: inout [ScanIssue],
        foldersVisited: inout Int,
        filesVisited: inout Int,
        scannedNodeCount: inout Int,
        progress: ScanProgressRelay
    ) async throws -> ScanNode {
        try Task.checkCancellation()

        scannedNodeCount += 1
        // Cooperative pacing keeps the background traversal from monopolizing a core.
        if scannedNodeCount.isMultiple(of: 256) {
            try await Task.sleep(for: .milliseconds(ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 8))
        }
        let path = url.path
        let identity = FileIdentity.read(path)
        let values = try url.resourceValues(forKeys: [
            .nameKey,
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileSizeKey,
            .totalFileAllocatedSizeKey,
            .isHiddenKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentAccessDateKey
        ])

        let isDirectory = values.isDirectory ?? false
        let isPackage = values.isPackage ?? false
        let isSymlink = values.isSymbolicLink ?? false
        let isHidden = values.isHidden ?? false
        let name = values.name ?? url.lastPathComponent

        let logicalSize = Int64(values.totalFileSize ?? values.fileSize ?? 0)
        let allocatedSize: Int64 = values.totalFileAllocatedSize.map(Int64.init) ?? logicalSize
        let mod = values.contentModificationDate
        let created = values.creationDate
        let accessed = values.contentAccessDate
        if depth > 0, isDirectory, let id = cachedPaths[path], let previous = cachedNodes[id], previous.modifiedAt == mod,
           !changedPaths.contains(where: { $0 == path || $0.hasPrefix(path + "/") }) {
            return previous
        }

        if isSymlink {
            issues.append(ScanIssue(path: path, message: "Skipped symbolic link", kind: .unknown))
            throw CocoaError(.fileReadNoSuchFile)
        }
        if isHidden && !options.includeHidden {
            issues.append(ScanIssue(path: path, message: "Skipped hidden entry", kind: .unknown))
            throw CocoaError(.featureUnsupported)
        }

        let app = ownership.resolve(path)
        let type = url.pathExtension.lowercased()

        if isDirectory {
            foldersVisited += 1

            guard depth < options.maxDepth else {
                issues.append(ScanIssue(path: path, message: "Scan depth limit reached; contents were not measured.", kind: .unavailable))
                let classif = FileIntelligence.classify(
                    path: path,
                    isDirectory: true,
                    isPackage: isPackage,
                    fileType: "folder",
                    logicalSize: logicalSize,
                    catalogAssociation: app,
                    uniformTypeIdentifier: values.contentType?.identifier
                )

                return ScanNode(
                    name: name,
                    path: path,
                    isDirectory: true,
                    logicalSize: 0,
                    allocatedSize: allocatedSize,
                    fileType: "folder",
                    itemCount: 0,
                    modifiedAt: mod,
                    createdAt: created,
                    lastOpenedAt: accessed,
                    classification: classif,
                    children: []
                )
            }

            let optionsForChildren: FileManager.DirectoryEnumerationOptions = options.includeHidden ? [] : [.skipsHiddenFiles]
            var directoryChildren: [ScanNode] = []
            let keys: [URLResourceKey] = [
                .isDirectoryKey,
                .isPackageKey,
                .isSymbolicLinkKey,
                .isHiddenKey,
                .nameKey,
                .fileSizeKey,
                .totalFileSizeKey,
                .totalFileAllocatedSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .contentAccessDateKey
            ]

            let childURLs: [URL]
            do {
                childURLs = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: optionsForChildren)
            } catch {
                issues.append(ScanIssue(path: path, message: error.localizedDescription, kind: issueKind(for: error)))
                let classif = FileIntelligence.classify(
                    path: path,
                    isDirectory: true,
                    isPackage: isPackage,
                    fileType: "folder",
                    logicalSize: logicalSize,
                    catalogAssociation: app,
                    uniformTypeIdentifier: values.contentType?.identifier
                )
                return ScanNode(
                    name: name,
                    path: path,
                    isDirectory: true,
                    logicalSize: 0,
                    allocatedSize: allocatedSize,
                    fileType: "folder",
                    itemCount: 0,
                    modifiedAt: mod,
                    createdAt: created,
                    lastOpenedAt: accessed,
                    classification: classif,
                    children: []
                )
            }

            await progress.publish(ScanProgress(
                phase: "Scanning",
                scannedItems: scannedNodeCount,
                foldersVisited: foldersVisited,
                filesVisited: filesVisited,
                currentPath: url.path
            ))

            for child in childURLs {
                do {
                    let childNode = try await scanNode(
                        at: child,
                        depth: depth + 1,
                        options: options,
                        ownership: ownership,
                        cachedNodes: cachedNodes,
                        cachedPaths: cachedPaths,
                        changedPaths: changedPaths,
                        issues: &issues,
                        foldersVisited: &foldersVisited,
                        filesVisited: &filesVisited,
                        scannedNodeCount: &scannedNodeCount,
                        progress: progress
                    )
                    if childNode.path.isEmpty { continue }
                    directoryChildren.append(childNode)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    issues.append(ScanIssue(path: child.path, message: error.localizedDescription, kind: issueKind(for: error)))
                    continue
                }
            }

            let logical = directoryChildren.reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize }
            let allocated = directoryChildren.reduce(into: Int64(0)) { $0 += $1.aggregatedAllocatedSize }
            let classif = FileIntelligence.classify(
                path: path,
                isDirectory: true,
                isPackage: isPackage,
                fileType: "folder",
                logicalSize: logical,
                catalogAssociation: app,
                uniformTypeIdentifier: values.contentType?.identifier
            )
            return ScanNode(
                name: name,
                path: path,
                isDirectory: true,
                logicalSize: logical,
                allocatedSize: allocated,
                fileType: "folder",
                itemCount: directoryChildren.count,
                modifiedAt: mod,
                createdAt: created,
                lastOpenedAt: accessed,
                classification: classif,
                children: directoryChildren
            )
        }

        filesVisited += 1
        let finalIdentity = FileIdentity.read(path)
        let stableIdentity = identity == finalIdentity ? finalIdentity : nil
        let classif = FileIntelligence.classify(
            path: path,
            isDirectory: false,
            isPackage: false,
            fileType: type,
            logicalSize: logicalSize,
            catalogAssociation: app,
            uniformTypeIdentifier: values.contentType?.identifier
        )

        return ScanNode(
            name: name,
            path: path,
            isDirectory: false,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            fileType: type,
            itemCount: 0,
            modifiedAt: mod,
            createdAt: created,
            lastOpenedAt: accessed,
            classification: classif,
            children: [],
            fileIdentity: stableIdentity
        )
    }
}
