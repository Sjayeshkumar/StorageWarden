import Foundation

public enum WorkspaceSection: String, Codable, Sendable, CaseIterable, Identifiable {
    case overview = "Overview"
    case storage = "Storage"
    case applications = "Applications"
    case documents = "Documents"
    case downloads = "Downloads"
    case movies = "Movies"
    case music = "Music"
    case pictures = "Pictures"
    case archives = "Archives"
    case developer = "Developer"
    case applicationData = "Application Data"
    case caches = "Caches"
    case other = "Other"
    case largestFiles = "Largest Files"
    case oldFiles = "Old Files"
    case duplicateCandidates = "Duplicate Candidates"
    case appStorage = "App Storage"
    case recentlyAdded = "Recently Added"
    case review = "Review"
    case trashHistory = "Trash History"
    case volumes = "Volumes"

    public var id: String { rawValue }
    public var displayTitle: String { rawValue }

    public var isCategory: Bool {
        switch self {
        case .applications, .documents, .downloads, .movies, .music, .pictures, .archives, .developer, .applicationData, .caches, .other:
            true
        default:
            false
        }
    }

    public var isAnalysis: Bool {
        switch self {
        case .largestFiles, .oldFiles, .duplicateCandidates, .appStorage, .recentlyAdded:
            true
        default:
            false
        }
    }

    public var isCleanup: Bool { self == .review || self == .trashHistory }

    public var category: StorageCategory? {
        switch self {
        case .applications: return .applicationBundle
        case .documents: return .documents
        case .downloads: return .downloads
        case .movies, .music, .pictures: return .media
        case .archives: return .archive
        case .developer: return .developer
        case .applicationData: return .applicationSupport
        case .caches: return .appCache
        case .other: return .unknown
        default: return nil
        }
    }

    public var icon: String {
        switch self {
        case .overview: return "chart.pie"
        case .storage: return "internaldrive"
        case .applications: return "app.badge"
        case .documents: return "doc"
        case .downloads: return "arrow.down.circle"
        case .movies: return "film"
        case .music: return "music.note"
        case .pictures: return "photo.on.rectangle"
        case .archives: return "doc.zipper"
        case .developer: return "hammer"
        case .applicationData: return "square.stack.3d.up"
        case .caches: return "hourglass"
        case .other: return "folder"
        case .largestFiles: return "arrow.up.right.square"
        case .oldFiles: return "clock.arrow.circlepath"
        case .duplicateCandidates: return "doc.on.doc"
        case .appStorage: return "shippingbox"
        case .recentlyAdded: return "sparkles"
        case .review: return "checklist.checked"
        case .trashHistory: return "trash"
        case .volumes: return "externaldrive"
        }
    }

    public static let topLevelSections: [WorkspaceSection] = [.overview, .storage]
    public static let categorySections: [WorkspaceSection] = [
        .applications,
        .documents,
        .downloads,
        .movies,
        .music,
        .pictures,
        .archives,
        .developer,
        .applicationData,
        .caches,
        .other
    ]
    public static let analysisSections: [WorkspaceSection] = [
        .largestFiles,
        .oldFiles,
        .duplicateCandidates,
        .appStorage,
        .recentlyAdded
    ]
    public static let cleanupSections: [WorkspaceSection] = [.review, .trashHistory]
    public static let allWorkspaceSections: [WorkspaceSection] = [
        .overview,
        .storage,
        .applications,
        .documents,
        .downloads,
        .movies,
        .music,
        .pictures,
        .archives,
        .developer,
        .applicationData,
        .caches,
        .other,
        .largestFiles,
        .oldFiles,
        .duplicateCandidates,
        .appStorage,
        .recentlyAdded,
        .review,
        .trashHistory,
        .volumes
    ]
}

public enum VisualizationMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case treemap = "Treemap"
    case sunburst = "Sunburst"
    case list = "List"
    case breakdown = "Breakdown"
    case distribution = "Distribution"

    public var id: String { rawValue }
}

public enum ScanMode: String, Codable, CaseIterable, Sendable {
    case standard = "Standard"
    case deep = "Deep"
}

public enum ImportanceLevel: String, Codable, Sendable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case unknown = "Unknown"
}

public enum CleanupSafety: String, Codable, Sendable, CaseIterable {
    case systemProtected = "System Critical"
    case importantData = "Important Data"
    case reviewCarefully = "Review Carefully"
    case usuallyRecreatable = "Usually Re-creatable"
    case safeToReview = "Safe to Review"
    case unknown = "Unknown"
}

public enum ClassificationConfidence: String, Codable, Sendable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

public enum StorageCategory: String, Codable, Sendable, CaseIterable {
    case system = "macOS System"
    case applicationBundle = "Application Bundle"
    case applicationSupport = "Application Support"
    case appCache = "Application Cache"
    case browserCache = "Browser Cache"
    case downloads = "Downloads"
    case documents = "Documents"
    case media = "Media"
    case archive = "Archive or Package"
    case virtualMachine = "Virtual Machine"
    case databases = "Databases"
    case logs = "Logs"
    case package = "Package"
    case developer = "Developer Artifacts"
    case unknown = "Unknown"
    case protected = "Protected"
}

public enum ScanIssueKind: String, Codable, Sendable, CaseIterable {
    case inaccessible = "Inaccessible"
    case protectedArea = "Protected Area"
    case transientError = "Transient Error"
    case unavailable = "Unavailable"
    case unknown = "Unknown"
}

public struct CategoryBucket: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let category: StorageCategory
    public let size: Int64
    public let itemCount: Int

    public init(id: UUID = UUID(), category: StorageCategory, size: Int64, itemCount: Int = 0) {
        self.id = id
        self.category = category
        self.size = size
        self.itemCount = itemCount
    }
}

public struct SizeDistributionBucket: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let lowerBound: Int64
    public let upperBound: Int64
    public let count: Int
    public let totalSize: Int64

    public init(
        id: UUID = UUID(),
        title: String,
        lowerBound: Int64,
        upperBound: Int64,
        count: Int,
        totalSize: Int64
    ) {
        self.id = id
        self.title = title
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.count = count
        self.totalSize = totalSize
    }
}

public struct ScanSummary: Codable, Sendable, Hashable {
    public let logicalSize: Int64
    public let allocatedSize: Int64
    public let itemCount: Int
    public let fileCount: Int
    public let folderCount: Int

    public init(logicalSize: Int64, allocatedSize: Int64, itemCount: Int, fileCount: Int, folderCount: Int) {
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.itemCount = itemCount
        self.fileCount = fileCount
        self.folderCount = folderCount
    }
}

public struct DuplicateCandidate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let signature: String
    public let totalSize: Int64
    public let occurrences: Int
    public let samplePath: String

    public init(id: UUID = UUID(), signature: String, totalSize: Int64, occurrences: Int, samplePath: String) {
        self.id = id
        self.signature = signature
        self.totalSize = totalSize
        self.occurrences = occurrences
        self.samplePath = samplePath
    }
}

public struct ScanIssue: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let path: String
    public let message: String
    public let kind: ScanIssueKind
    public let timestamp: Date

    public init(id: UUID = UUID(), path: String, message: String, kind: ScanIssueKind, timestamp: Date = Date()) {
        self.id = id
        self.path = path
        self.message = message
        self.kind = kind
        self.timestamp = timestamp
    }
}

public struct ScanProgress: Codable, Sendable {
    public let phase: String
    public let scannedItems: Int
    public let foldersVisited: Int
    public let filesVisited: Int
    public let currentPath: String
    public let startedAt: Date

    public var totalVisited: Int { foldersVisited + filesVisited }
    public var coverageFraction: Double {
        let denominator = max(1, max(scannedItems, foldersVisited + filesVisited))
        let numerator = foldersVisited + filesVisited
        return denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    public init(
        phase: String = "Ready",
        scannedItems: Int = 0,
        foldersVisited: Int = 0,
        filesVisited: Int = 0,
        currentPath: String = "",
        startedAt: Date = Date()
    ) {
        self.phase = phase
        self.scannedItems = scannedItems
        self.foldersVisited = foldersVisited
        self.filesVisited = filesVisited
        self.currentPath = currentPath
        self.startedAt = startedAt
    }
}

public struct FileClassification: Codable, Hashable, Sendable {
    public let category: StorageCategory
    public let importance: ImportanceLevel
    public let cleanupRisk: CleanupSafety
    public let confidence: ClassificationConfidence
    public let explanation: String
    public let deletionConsequences: String
    public let canBeRecreated: Bool
    public let removeAllowed: Bool
    public let defaultAction: String
    public let associatedApplication: String?

    public init(
        category: StorageCategory,
        importance: ImportanceLevel,
        cleanupRisk: CleanupSafety,
        confidence: ClassificationConfidence,
        explanation: String,
        deletionConsequences: String,
        canBeRecreated: Bool,
        removeAllowed: Bool,
        defaultAction: String,
        associatedApplication: String? = nil
    ) {
        self.category = category
        self.importance = importance
        self.cleanupRisk = cleanupRisk
        self.confidence = confidence
        self.explanation = explanation
        self.deletionConsequences = deletionConsequences
        self.canBeRecreated = canBeRecreated
        self.removeAllowed = removeAllowed
        self.defaultAction = defaultAction
        self.associatedApplication = associatedApplication
    }
}

public struct VolumeCapacity: Codable, Hashable, Sendable {
    public let total: Int64
    public let available: Int64
    public let used: Int64

    public init(total: Int64, available: Int64, used: Int64) {
        self.total = total
        self.available = available
        self.used = used
    }

    public var capacityUsedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, Double(used) / Double(total)))
    }

    public init() {
        self.total = 0
        self.available = 0
        self.used = 0
    }
}

public struct VolumeScanResult: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let volumeName: String
    public let volumeURL: String
    public let scanStartedAt: Date
    public let scanCompletedAt: Date
    public let rootNode: ScanNode
    public let summary: ScanSummary
    public let accessibilityIssues: [ScanIssue]
    public let capacity: VolumeCapacity

    public init(
        id: UUID = UUID(),
        volumeName: String,
        volumeURL: String,
        scanStartedAt: Date,
        scanCompletedAt: Date,
        rootNode: ScanNode,
        summary: ScanSummary,
        accessibilityIssues: [ScanIssue] = [],
        capacity: VolumeCapacity = .init()
    ) {
        self.id = id
        self.volumeName = volumeName
        self.volumeURL = volumeURL
        self.scanStartedAt = scanStartedAt
        self.scanCompletedAt = scanCompletedAt
        self.rootNode = rootNode
        self.summary = summary
        self.accessibilityIssues = accessibilityIssues
        self.capacity = capacity
    }
}

public struct ScanSnapshot: Codable, Sendable {
    public let generatedAt: Date
    public let volumeResults: [VolumeScanResult]
    public let trashHistory: [TrashOperation]

    public init(generatedAt: Date, volumeResults: [VolumeScanResult], trashHistory: [TrashOperation] = []) {
        self.generatedAt = generatedAt
        self.volumeResults = volumeResults
        self.trashHistory = trashHistory
    }
}

public struct TrashOperation: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let size: Int64
    public let timestamp: Date
    public let success: Bool
    public let error: String?

    public init(
        id: UUID = UUID(),
        path: String,
        size: Int64,
        timestamp: Date = Date(),
        success: Bool,
        error: String? = nil
    ) {
        self.id = id
        self.path = path
        self.size = size
        self.timestamp = timestamp
        self.success = success
        self.error = error
    }
}

public struct SelectionSummary: Codable, Sendable {
    public let count: Int
    public let totalLogicalSize: Int64
    public let totalAllocatedSize: Int64
    public let lowRiskLogical: Int64
    public let reviewLogical: Int64
    public let importantLogical: Int64
    public let protectedLogical: Int64

    public init(
        count: Int,
        totalLogicalSize: Int64,
        totalAllocatedSize: Int64,
        lowRiskLogical: Int64,
        reviewLogical: Int64,
        importantLogical: Int64,
        protectedLogical: Int64
    ) {
        self.count = count
        self.totalLogicalSize = totalLogicalSize
        self.totalAllocatedSize = totalAllocatedSize
        self.lowRiskLogical = lowRiskLogical
        self.reviewLogical = reviewLogical
        self.importantLogical = importantLogical
        self.protectedLogical = protectedLogical
    }
}

public struct DeletionPreview: Codable, Sendable, Hashable {
    public let id: UUID
    public let title: String
    public let items: [ScanNode]
    public let totalLogicalSize: Int64
    public let totalAllocatedSize: Int64

    public init(
        id: UUID = UUID(),
        title: String,
        items: [ScanNode],
        totalLogicalSize: Int64,
        totalAllocatedSize: Int64
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.totalLogicalSize = totalLogicalSize
        self.totalAllocatedSize = totalAllocatedSize
    }
}

public final class ScanNode: Identifiable, Codable, Hashable, Sendable {
    // Immutable records are shared by the tree, lookup tables and result lists.
    // Identity is the scan ID; comparing or hashing never traverses descendants.
    public static func == (lhs: ScanNode, rhs: ScanNode) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let logicalSize: Int64
    public let allocatedSize: Int64
    public let fileType: String
    public let itemCount: Int
    public let modifiedAt: Date?
    public let createdAt: Date?
    public let lastOpenedAt: Date?
    public let classification: FileClassification
    public let children: [ScanNode]

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        logicalSize: Int64,
        allocatedSize: Int64,
        fileType: String,
        itemCount: Int,
        modifiedAt: Date? = nil,
        createdAt: Date? = nil,
        lastOpenedAt: Date? = nil,
        classification: FileClassification,
        children: [ScanNode] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.fileType = fileType
        self.itemCount = itemCount
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.classification = classification
        self.children = children
    }

    public var displayName: String {
        if name.isEmpty { return URL(fileURLWithPath: path).lastPathComponent }
        return name
    }

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public var aggregatedLogicalSize: Int64 {
        logicalSize
    }

    public var aggregatedAllocatedSize: Int64 {
        allocatedSize
    }

    public var aggregatedItemCount: Int {
        if !isDirectory {
            return 1
        }
        return 1 + children.reduce(into: 0) { $0 += $1.aggregatedItemCount }
    }

    public var aggregatedFolderCount: Int {
        if !isDirectory { return 0 }
        return 1 + children.reduce(into: 0) { $0 += $1.aggregatedFolderCount }
    }

    public var aggregatedFileCount: Int {
        if !isDirectory { return 1 }
        return children.reduce(into: 0) { $0 += $1.aggregatedFileCount }
    }

    public var nonOptionalChildren: [ScanNode] { children }

    public func flattened(includeSelf: Bool = false, maxDepth: Int? = nil, _ currentDepth: Int = 0) -> [ScanNode] {
        var list: [ScanNode] = []
        if includeSelf { list.append(self) }

        guard isDirectory else { return list }
        guard maxDepth == nil || currentDepth < (maxDepth ?? Int.max) else { return list }

        for child in children {
            list.append(contentsOf: child.flattened(includeSelf: true, maxDepth: maxDepth, currentDepth + 1))
        }
        return list
    }

    public func find(id targetID: UUID) -> ScanNode? {
        if self.id == targetID { return self }
        for child in children {
            if let match = child.find(id: targetID) {
                return match
            }
        }
        return nil
    }

    public func find(path targetPath: String) -> ScanNode? {
        if path == targetPath { return self }
        for child in children {
            if let match = child.find(path: targetPath) {
                return match
            }
        }
        return nil
    }

    public func relativePath(to base: ScanNode) -> String {
        if base.path.isEmpty { return displayName }
        if path == base.path { return displayName }
        let normalizedBase = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
        if path.hasPrefix(normalizedBase) {
            let remainder = String(path.dropFirst(normalizedBase.count))
            return remainder.isEmpty ? "." : remainder.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return path
    }

    public func categoryPath(for target: StorageCategory) -> [ScanNode] {
        if classification.category == target {
            return [self]
        }
        guard isDirectory else { return [] }
        return children.flatMap { $0.categoryPath(for: target) }
    }

    public func withSafeChildrenSort(_ comparator: (ScanNode, ScanNode) -> Bool) -> ScanNode {
        guard isDirectory else { return self }
        let sorted = children.sorted(by: comparator)
        return ScanNode(
            id: id,
            name: name,
            path: path,
            isDirectory: isDirectory,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            fileType: fileType,
            itemCount: itemCount,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            lastOpenedAt: lastOpenedAt,
            classification: classification,
            children: sorted.map { $0.withSafeChildrenSort(comparator) }
        )
    }

    public static let placeholder = ScanNode(
        name: "",
        path: "",
        isDirectory: false,
        logicalSize: 0,
        allocatedSize: 0,
        fileType: "",
        itemCount: 0,
        modifiedAt: nil,
        createdAt: nil,
        lastOpenedAt: nil,
        classification: FileClassification(
            category: .unknown,
            importance: .unknown,
            cleanupRisk: .unknown,
            confidence: .low,
            explanation: "No node selected",
            deletionConsequences: "Nothing selected",
            canBeRecreated: false,
            removeAllowed: false,
            defaultAction: "Select one item",
            associatedApplication: nil
        )
    )
}

public extension ScanSummary {
    static func from(_ rootNodes: [ScanNode]) -> ScanSummary {
        var logical: Int64 = 0
        var allocated: Int64 = 0
        var files = 0
        var folders = 0

        for node in rootNodes {
            logical += node.aggregatedLogicalSize
            allocated += node.aggregatedAllocatedSize
            files += node.aggregatedFileCount
            folders += node.aggregatedFolderCount
        }

        return ScanSummary(
            logicalSize: logical,
            allocatedSize: allocated,
            itemCount: logicalNodesCount(rootNodes),
            fileCount: files,
            folderCount: folders
        )
    }

    private static func logicalNodesCount(_ roots: [ScanNode]) -> Int {
        roots.reduce(into: 0) { total, node in
            total += node.flattened(includeSelf: true).count
        }
    }
}

public extension Array where Element == ScanNode {
    func totals() -> ScanSummary {
        let logical = reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize }
        let allocated = reduce(into: Int64(0)) { $0 += $1.aggregatedAllocatedSize }
        let files = reduce(into: 0) { $0 += $1.aggregatedFileCount }
        let folders = reduce(into: 0) { $0 += $1.aggregatedFolderCount }
        return ScanSummary(
            logicalSize: logical,
            allocatedSize: allocated,
            itemCount: reduce(into: 0) { $0 += $1.flattened(includeSelf: true).count },
            fileCount: files,
            folderCount: folders
        )
    }

    func categoryBuckets() -> [CategoryBucket] {
        var dictionary: [StorageCategory: (size: Int64, count: Int)] = [:]
        for node in self.flatMap({ $0.flattened(includeSelf: true) }) where !node.isDirectory {
            let existing = dictionary[node.classification.category] ?? (0, 0)
            dictionary[node.classification.category] = (existing.size + node.aggregatedLogicalSize, existing.count + 1)
        }

        return dictionary.map {
            CategoryBucket(category: $0.key, size: $0.value.size, itemCount: $0.value.count)
        }
        .sorted { $0.size > $1.size }
    }

    func totalsBySection(for section: WorkspaceSection) -> ScanSummary {
        guard let category = section.category else {
            return self.totals()
        }
        let selected = self.filter { $0.classification.category == category }
        return selected.totals()
    }

    func topFolders(limit: Int = 12) -> [ScanNode] {
        return self
            .filter { $0.isDirectory }
            .sorted { $0.aggregatedLogicalSize > $1.aggregatedLogicalSize }
            .prefix(limit)
            .map { $0 }
    }

    func largestFiles(limit: Int = 200) -> [ScanNode] {
        return flatMap { $0.flattened(includeSelf: true).filter { !$0.isDirectory && $0.aggregatedLogicalSize > 0 } }
            .sorted { $0.aggregatedLogicalSize > $1.aggregatedLogicalSize }
            .prefix(limit)
            .map { $0 }
    }

    func oldestFiles(limit: Int = 200, olderThan days: Int = 180) -> [ScanNode] {
        let cutoff = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        return flatMap { $0.flattened(includeSelf: true) }
            .filter { !$0.isDirectory && $0.modifiedAt != nil && $0.modifiedAt! <= cutoff }
            .sorted { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func recentlyCreatedNodes(limit: Int = 200, since days: Int = 60) -> [ScanNode] {
        let cutoff = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        return flatMap { $0.flattened(includeSelf: true) }
            .filter { $0.createdAt != nil ? $0.createdAt! >= cutoff : false }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func appStorageGroups() -> [ScanNode] {
        var map: [String: [ScanNode]] = [:]
        for node in flatMap({ $0.flattened(includeSelf: true) }) {
            guard let app = node.classification.associatedApplication, !app.isEmpty else { continue }
            map[app, default: []].append(node)
        }

        return map.map { pair in
            let nodes = pair.value
            let totalLogical = nodes.reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize }
            let totalAllocated = nodes.reduce(into: Int64(0)) { $0 += $1.aggregatedAllocatedSize }
            let itemCount = nodes.count
            let risks = nodes.map { $0.classification.cleanupRisk }
            let risky = risks.max(by: { $0.priority < $1.priority }) ?? .safeToReview

            let classification = FileClassification(
                category: .applicationBundle,
                importance: .medium,
                cleanupRisk: risky,
                confidence: .medium,
                explanation: "Items tied to this application.\nUse one-by-one review before deleting any top-level folder.",
                deletionConsequences: "Removing these items can impact app data and local state.",
                canBeRecreated: false,
                removeAllowed: false,
                defaultAction: "Review each app item before cleanup.",
                associatedApplication: pair.key
            )

            return ScanNode(
                name: pair.key,
                path: nodes.first?.path ?? pair.key,
                isDirectory: true,
                logicalSize: totalLogical,
                allocatedSize: totalAllocated,
                fileType: "folder",
                itemCount: itemCount,
                modifiedAt: nil,
                createdAt: nil,
                lastOpenedAt: nil,
                classification: classification,
                children: nodes
            )
        }
        .sorted { $0.aggregatedLogicalSize > $1.aggregatedLogicalSize }
    }

    func duplicateCandidates() -> [ScanNode] {
        let candidates = flatMap { $0.flattened(includeSelf: true).filter { !$0.isDirectory && $0.aggregatedLogicalSize > 0 } }

        var map: [String: [ScanNode]] = [:]
        for node in candidates {
            let signature = "\(node.aggregatedLogicalSize):\(node.fileType.lowercased())"
            map[signature, default: []].append(node)
        }

        let grouped = map.filter { $0.value.count > 1 }
        let ranked = grouped
            .sorted { lhs, rhs in
                lhs.value.reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize } > rhs.value.reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize }
            }

        return ranked.flatMap { _, nodes in
            nodes.sorted { $0.aggregatedLogicalSize > $1.aggregatedLogicalSize }
        }
    }

    func sizeDistributionBuckets() -> [SizeDistributionBucket] {
        let files = flatMap { $0.flattened(includeSelf: true).filter { !$0.isDirectory && $0.aggregatedLogicalSize > 0 } }
        let cutoffs: [(String, Int64, Int64)] = [
            ("< 1 MB", 0, 1024 * 1024 - 1),
            ("1 MB - 10 MB", 1024 * 1024, 10 * 1024 * 1024 - 1),
            ("10 MB - 100 MB", 10 * 1024 * 1024, 100 * 1024 * 1024 - 1),
            ("100 MB - 1 GB", 100 * 1024 * 1024, 1024 * 1024 * 1024 - 1),
            ("1 GB - 5 GB", 1024 * 1024 * 1024, 5 * 1024 * 1024 * 1024 - 1),
            ("5 GB - 10 GB", 5 * 1024 * 1024 * 1024, 10 * 1024 * 1024 * 1024 - 1),
            (">= 10 GB", 10 * 1024 * 1024 * 1024, Int64.max)
        ]

        var results: [SizeDistributionBucket] = []
        for (title, lower, upper) in cutoffs {
            let bucketItems = files.filter { $0.aggregatedLogicalSize >= lower && $0.aggregatedLogicalSize <= upper }
            let total = bucketItems.reduce(into: Int64(0)) { $0 += $1.aggregatedLogicalSize }
            results.append(SizeDistributionBucket(title: title, lowerBound: lower, upperBound: upper, count: bucketItems.count, totalSize: total))
        }
        return results
    }
}

private extension CleanupSafety {
    var priority: Int {
        switch self {
        case .safeToReview: return 0
        case .usuallyRecreatable: return 1
        case .reviewCarefully: return 2
        case .importantData: return 3
        case .systemProtected: return 4
        case .unknown: return 5
        }
    }
}
