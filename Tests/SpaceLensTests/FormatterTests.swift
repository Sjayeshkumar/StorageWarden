import XCTest
@testable import SpaceLens

final class FormatterTests: XCTestCase {
    func testBytesFormattingProducesMB() {
        let value = Int64(2_097_152)
        XCTAssertTrue(Formatters.bytes(value).contains("MB"))
    }

    func testDateFormattingIsNonEmpty() {
        let formatted = Formatters.dateTime(Date(timeIntervalSince1970: 0))
        XCTAssertFalse(formatted.isEmpty)
    }
}

final class StorageCorrectnessTests: XCTestCase {
    private func node(_ name: String, size: Int64, children: [ScanNode] = []) -> ScanNode {
        ScanNode(name: name, path: "/fixture/" + name, isDirectory: !children.isEmpty, logicalSize: size, allocatedSize: size / 2, fileType: "", itemCount: children.count, classification: FileIntelligence.classify(path: "/fixture/" + name, isDirectory: !children.isEmpty, isPackage: false, fileType: "", logicalSize: size, catalogAssociation: nil), children: children)
    }

    func testNestedSizesAreNotCountedAgain() {
        let file = node("file", size: 100)
        let folder = node("folder", size: 100, children: [file])
        let root = node("root", size: 100, children: [folder])
        XCTAssertEqual(root.aggregatedLogicalSize, 100)
        XCTAssertEqual(root.aggregatedAllocatedSize, 50)
        XCTAssertEqual([root].categoryBuckets().reduce(0) { $0 + $1.size }, 100)
    }

    func testTreemapAreaMatchesSizesWithoutOverlap() {
        let items = [node("a", size: 600), node("b", size: 300), node("c", size: 100)]
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
        let placements = MapLayout.rectangles(items, in: bounds)
        XCTAssertEqual(placements.count, 3)
        for item in placements {
            XCTAssertEqual(item.rect.width * item.rect.height / 150000, Double(item.node.logicalSize) / 1000, accuracy: 0.00001)
            XCTAssertTrue(bounds.contains(item.rect))
        }
        XCTAssertFalse(placements[0].rect.intersects(placements[2].rect.insetBy(dx: 0.1, dy: 0.1)))
    }

    func testBuildNamedFolderIsNotDisposable() {
        let classification = FileIntelligence.classify(path: "/Users/example/valuable-build-project", isDirectory: true, isPackage: false, fileType: "folder", logicalSize: 100, catalogAssociation: nil)
        XCTAssertFalse(classification.removeAllowed)
        XCTAssertFalse(classification.canBeRecreated)
    }
}

final class BackgroundIndexTests: XCTestCase {
    private func file(_ path: String, size: Int64) -> ScanNode {
        ScanNode(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isDirectory: false, logicalSize: size, allocatedSize: size, fileType: "txt", itemCount: 0, classification: FileIntelligence.classify(path: path, isDirectory: false, isPackage: false, fileType: "txt", logicalSize: size, catalogAssociation: nil))
    }
    private func volume(_ root: ScanNode) -> VolumeScanResult {
        VolumeScanResult(volumeName: "Fixture", volumeURL: root.path, scanStartedAt: Date(), scanCompletedAt: Date(), rootNode: root, summary: [root].totals())
    }
    func testPersistedIndexRoundTripAndPermissions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = ScanSnapshot(generatedAt: Date(), volumeResults: [volume(file("/fixture/data.txt", size: 123))])
        let writer = StorageSnapshotStore(directory: directory)
        let error = await writer.persist(original)
        XCTAssertNil(error)
        let reopened = await StorageSnapshotStore(directory: directory).loadSnapshot()
        XCTAssertEqual(reopened?.volumeResults.first?.rootNode.logicalSize, 123)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("index.plist").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testChangedSubtreeUpdatesAncestorsAndPreservesSibling() async {
        let a = file("/fixture/a.txt", size: 100), b = file("/fixture/b.txt", size: 200)
        let root = ScanNode(name: "fixture", path: "/fixture", isDirectory: true, logicalSize: 300, allocatedSize: 300, fileType: "folder", itemCount: 2, classification: a.classification, children: [a, b])
        let updated = await IndexWorker().replace(in: volume(root), path: a.path, replacement: file(a.path, size: 500), issues: [])
        XCTAssertEqual(updated.rootNode.logicalSize, 700)
        XCTAssertEqual(updated.rootNode.children.last?.id, b.id)
        let index = StorageIndex(root: updated.rootNode)
        XCTAssertEqual(index.byID[b.id]?.logicalSize, 200)
        XCTAssertEqual(index.buckets.reduce(0) { $0 + $1.size }, 700)
    }
    func testMissingRootDoesNotTriggerHomeScan() async {
        do {
            _ = try await StorageScanner().scan(volumes: [URL(fileURLWithPath: "/does-not-exist-warden-fixture")], catalog: AppCatalog(), progress: ScanProgressRelay())
            XCTFail("A missing root must fail, not fall back to scanning the home folder")
        } catch { XCTAssertTrue(error is CocoaError) }
    }
    func testRealScannerIncludesHiddenFilesAndCorrectBytes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(repeating: 1, count: 100).write(to: directory.appendingPathComponent("visible.txt"))
        try Data(repeating: 2, count: 200).write(to: directory.appendingPathComponent(".hidden"))
        let result = try await StorageScanner(options: .init(includeHidden: true)).scan(volumes: [directory], catalog: AppCatalog(), progress: ScanProgressRelay())
        XCTAssertEqual(result.first?.rootNode.logicalSize, 300)
        XCTAssertEqual(result.first?.rootNode.children.count, 2)
    }
    func testLargeIndexLookupPreparation() {
        let files = (0..<20_000).map { file("/fixture/\($0).txt", size: Int64($0)) }
        let root = ScanNode(name: "fixture", path: "/fixture", isDirectory: true, logicalSize: files.reduce(0) { $0 + $1.logicalSize }, allocatedSize: 0, fileType: "folder", itemCount: files.count, classification: files[0].classification, children: files)
        let start = Date()
        let index = StorageIndex(root: root)
        XCTAssertEqual(index.byID.count, 20_001)
        XCTAssertEqual(index.byID[files[19_999].id]?.logicalSize, 19_999)
        print("WARDEN_INDEX_20000_SECONDS=\(Date().timeIntervalSince(start))")
    }
}

final class RecordSharingTests: XCTestCase {
    func testIndexReusesImmutableRecords() {
        let item = ScanNode.placeholder
        let index = StorageIndex(root: item)
        XCTAssertTrue(index.byID[item.id] === item)
    }
    func testActivitySampleReadsOwnProcess() async {
        let snapshot = await ActivitySampler().sample()
        let own = snapshot.processes.first { $0.id == ProcessInfo.processInfo.processIdentifier }
        XCTAssertNotNil(own)
        XCTAssertGreaterThan(own?.memory ?? 0, 0)
        XCTAssertNil(own?.cpu, "The first CPU sample has no baseline and must not claim zero usage")
    }
}

final class CPUCounterTests: XCTestCase {
    func testAppleSiliconTimebaseConversion() {
        XCTAssertEqual(CPUMath.percent(ticks: 24_000_000, elapsed: 1, nanosPerTick: 125.0 / 3.0), 100, accuracy: 0.001)
    }
    func testMulticoreCPUCanExceed100Percent() {
        XCTAssertEqual(CPUMath.percent(ticks: 2_000_000_000, elapsed: 1, nanosPerTick: 1), 200, accuracy: 0.001)
    }
}
