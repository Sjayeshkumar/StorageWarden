import AppKit
import Charts
import QuickLook
import SwiftUI

struct StorageBrowserView: View {
    let volume: VolumeScanResult
    let section: WorkspaceSection
    let rootNode: ScanNode
    let nodes: [ScanNode]
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""
    @StateObject private var results = BrowserResults()
    @State private var sortOrder = [KeyPathComparator(\ScanNode.logicalSize, order: .reverse)]
    @State private var previewURL: URL?
    private var source: [ScanNode] { section == .storage ? rootNode.children : nodes }
    private var rows: [ScanNode] { results.rows }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if section == .storage {
                    Button { session.setCurrentFolder(rootNode.url.deletingLastPathComponent().path) } label: { Image(systemName: "chevron.left") }
                        .disabled(rootNode.path == volume.rootNode.path).help("Enclosing folder")
                    Button { session.setCurrentFolder(volume.rootNode.path) } label: { Image(systemName: "house") }.help("Scan root")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rootNode.displayName).font(.headline)
                        Text(rootNode.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                } else {
                    Text("\(rows.count.formatted()) items").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search this view", text: $searchText).textFieldStyle(.plain)
                    if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary) }
                }.padding(8).frame(width: 200).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            }.padding(16)
            if section == .duplicateCandidates {
                Label("Candidates share size and file type. Contents have not been compared; these are not verified duplicates.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 10)
            }
            if section == .storage {
                HStack {
                    Picker("Visualization", selection: $session.selectedVisualizationMode) {
                        ForEach(VisualizationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                    }.pickerStyle(.segmented).frame(maxWidth: 460)
                    Spacer()
                    Text(rootNode.logicalSize.asStorageSize).font(.headline.monospacedDigit())
                }.padding(.horizontal, 16).padding(.bottom, 12)
                if session.selectedVisualizationMode != .list && !rows.isEmpty {
                    visualization.frame(height: session.selectedVisualizationMode == .sunburst ? 320 : 250)
                        .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
            Divider()
            Table(rows, selection: $session.selectedNodeIDs, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.displayName) { node in
                    HStack(spacing: 9) {
                        Image(systemName: node.classification.category == .applicationBundle ? "app.fill" : node.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.system(size: 19)).foregroundStyle(storageColor(node.classification.category))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.displayName).lineLimit(1)
                            if section != .storage {
                                Text(node.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                        if node.isDirectory {
                            Spacer(minLength: 2)
                            Button { session.explore(node) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless).help("Explore folder")
                        }
                    }.padding(.vertical, 4)
                }.width(min: 180, ideal: 300)
                TableColumn("Size", value: \.logicalSize) { node in
                    Text(node.logicalSize.asStorageSize).monospacedDigit().fontWeight(.medium)
                }.width(min: 85, ideal: 100, max: 120)
                TableColumn("Kind") { node in
                    Text(node.isDirectory ? "Folder" : node.fileType.isEmpty ? "File" : node.fileType.uppercased()).foregroundStyle(.secondary)
                }.width(min: 55, ideal: 70, max: 90)
                TableColumn("Review") { node in
                    Text(node.classification.cleanupRisk.rawValue).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }.width(min: 110, ideal: 140, max: 170)
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first, let node = session.node(with: id) {
                    Button("Reveal in Finder") { session.openNodeInFinder(node) }
                    Button("Quick Look") { previewURL = node.url }
                    if node.isDirectory { Button("Explore Folder") { session.explore(node) } }
                    Divider()
                    Button("Review for Trash") { session.selectedNodeIDs = ids; session.requestDeleteForSelection() }.disabled(!ids.allSatisfy { session.node(with: $0).map(session.canDelete(node:)) == true })
                }
            } primaryAction: { ids in
                if let id = ids.first, let node = session.node(with: id) {
                    if node.isDirectory { session.explore(node) } else { previewURL = node.url }
                }
            }
            .overlay {
                if results.loading {
                    ProgressView("Preparing this view…")
                } else if rows.isEmpty {
                    ContentUnavailableView(searchText.isEmpty ? "No matching files in this scan" : "No search results", systemImage: "folder.badge.questionmark", description: Text(searchText.isEmpty ? "Scan another folder or check skipped locations for missing data." : "Try a different name or path."))
                }
            }
            Divider()
            HStack(spacing: 12) {
                if session.selectedNodeIDs.isEmpty {
                    Text("\(rows.count.formatted()) items").foregroundStyle(.secondary)
                    Spacer()
                    Text("Double-click a folder to explore").foregroundStyle(.secondary)
                } else {
                    Text("\(session.selectionSummary.count) selected").fontWeight(.medium)
                    Text(session.selectionSummary.totalLogicalSize.asStorageSize).monospacedDigit()
                    Spacer()
                    Button("Clear") { session.selectedNodeIDs.removeAll() }
                    Button("Review for Trash") { session.requestDeleteForSelection() }.buttonStyle(.borderedProminent).disabled(!session.canDeleteSelection)
                }
            }.font(.caption).padding(12)
        }
        .quickLookPreview($previewURL)
        .task(id: BrowserRequest(root: rootNode.id, revision: session.revision, search: searchText, order: sortOrder)) {
            await results.load(source, text: searchText, order: sortOrder)
        }
    }

    @ViewBuilder private var visualization: some View {
        switch session.selectedVisualizationMode {
        case .treemap: TreemapView(nodes: rows, revision: results.revision)
        case .sunburst: SunburstView(nodes: rows, revision: results.revision)
        case .breakdown:
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(rows.prefix(20)) { node in
                        Button { session.explore(node) } label: {
                            VStack(spacing: 5) {
                                HStack { Text(node.displayName).lineLimit(1); Spacer(); Text(node.logicalSize.asStorageSize).monospacedDigit() }
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 3).fill(storageColor(node.classification.category)).frame(width: geometry.size.width * min(1, CGFloat(node.logicalSize) / CGFloat(max(1, rootNode.logicalSize))))
                                }.frame(height: 5)
                            }.padding(5)
                        }.buttonStyle(.plain)
                    }
                }
            }
        case .distribution:
            let buckets = results.distribution
            Chart(buckets, id: \.title) { bucket in
                BarMark(x: .value("Size range", bucket.title), y: .value("Files", bucket.count)).foregroundStyle(.teal.gradient)
                    .annotation(position: .top) {
                        VStack(spacing: 2) { Text("\(bucket.count)"); Text(bucket.totalSize.asStorageSize).foregroundStyle(.secondary) }.font(.caption2)
                    }
            }.chartYAxisLabel("File count").padding(.top, 25)
        case .list: EmptyView()
        }
    }
}

private let mapColors: [Color] = [.teal, .orange, .blue, .pink, .green, .indigo, .cyan, .yellow]

private struct MapEntry: Identifiable, Sendable {
    let id: String
    let node: ScanNode?
    let name: String
    let size: Int64
    let branch: Int
}
private struct RadialItem: Identifiable, Sendable {
    let id: String
    let entry: MapEntry
    let start: Double
    let end: Double
    let depth: Int
}
private struct PreparedMap: Sendable {
    var entries: [MapEntry] = []
    var rings: [RadialItem] = []
    var total: Int64 = 0
    var grouped = false
}
private actor MapWorker {
    func prepare(_ nodes: [ScanNode]) -> PreparedMap {
        var result = PreparedMap()
        let sorted = nodes.filter { $0.logicalSize > 0 }.sorted { $0.logicalSize > $1.logicalSize }
        result.total = sorted.reduce(0) { $0 + $1.logicalSize }
        func entry(_ node: ScanNode, branch: Int) -> MapEntry { MapEntry(id: node.id.uuidString, node: node, name: node.displayName, size: node.logicalSize, branch: branch) }
        result.entries = sorted.prefix(48).enumerated().map { entry($0.element, branch: $0.offset) }
        if sorted.count > 48 {
            result.grouped = true
            result.entries.append(MapEntry(id: "remaining", node: nil, name: "\(sorted.count - 48) smaller items", size: sorted.dropFirst(48).reduce(0) { $0 + $1.logicalSize }, branch: 48))
        }
        func ring(_ item: MapEntry, start: Double, span: Double, depth: Int) {
            guard depth < 4, (depth == 0 || result.rings.count < 400), span > 0.002 else { return }
            result.rings.append(RadialItem(id: item.id, entry: item, start: start, end: start + span, depth: depth))
            guard let node = item.node, node.logicalSize > 0 else { return }
            var cursor = start
            for child in node.children.sorted(by: { $0.logicalSize > $1.logicalSize }) where child.logicalSize > 0 {
                let portion = span * Double(child.logicalSize) / Double(node.logicalSize)
                ring(entry(child, branch: item.branch), start: cursor, span: portion, depth: depth + 1)
                cursor += portion
                if result.rings.count >= 400 { break }
            }
        }
        var cursor = 0.0
        for item in result.entries {
            let span = Double(item.size) / Double(max(1, result.total))
            ring(item, start: cursor, span: span, depth: 0)
            cursor += span
        }
        return result
    }
}
@MainActor
private final class MapModel: ObservableObject {
    @Published var data = PreparedMap()
    private let worker = MapWorker()
    func load(_ nodes: [ScanNode]) async {
        let value = await worker.prepare(nodes)
        if !Task.isCancelled { data = value }
    }
}

struct TreemapView: View {
    let nodes: [ScanNode]
    let revision: UUID
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = MapModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let placements = entryRectangles(model.data.entries, in: CGRect(origin: .zero, size: geometry.size))
                ZStack(alignment: .topLeading) {
                    ForEach(placements, id: \.entry.id) { placement in
                        Button {
                            if let node = placement.entry.node { session.explore(node) }
                        } label: {
                            RoundedRectangle(cornerRadius: 5).fill(mapColors[placement.entry.branch % mapColors.count].opacity(0.8).gradient)
                                .overlay(alignment: .topLeading) {
                                    if placement.rect.width > 70 && placement.rect.height > 45 {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(placement.entry.name).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                                            Text(placement.entry.size.asStorageSize).font(.system(size: 11)).monospacedDigit()
                                        }.padding(9).foregroundStyle(.black)
                                    }
                                }.clipped()
                        }.buttonStyle(.plain).disabled(placement.entry.node == nil)
                            .frame(width: max(0, placement.rect.width - 2), height: max(0, placement.rect.height - 2))
                            .position(x: placement.rect.midX, y: placement.rect.midY)
                            .help("\(placement.entry.name) · \(placement.entry.size.asStorageSize)")
                            .accessibilityLabel("\(placement.entry.name), \(placement.entry.size.asStorageSize)")
                    }
                }
            }
            Text(model.data.grouped ? "Largest 48 items shown individually. Smaller items are grouped; every file remains in the list below." : "Area represents size. Click a folder to explore; select a file to inspect it.")
                .font(.caption).foregroundStyle(.secondary)
        }.task(id: revision) { await model.load(nodes) }
    }
}

private struct EntryPlacement { let entry: MapEntry; let rect: CGRect }
private func entryRectangles(_ items: [MapEntry], in rect: CGRect) -> [EntryPlacement] {
    guard !items.isEmpty else { return [] }
    if items.count == 1 { return [EntryPlacement(entry: items[0], rect: rect)] }
    let total = items.reduce(0.0) { $0 + Double($1.size) }
    guard total > 0 else { return [] }
    var sum = 0.0, split = 1
    for index in 0..<(items.count - 1) { sum += Double(items[index].size); split = index + 1; if sum >= total / 2 { break } }
    let fraction = CGFloat(sum / total)
    let first: CGRect, second: CGRect
    if rect.width >= rect.height {
        first = CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height)
        second = CGRect(x: first.maxX, y: rect.minY, width: rect.width - first.width, height: rect.height)
    } else {
        first = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * fraction)
        second = CGRect(x: rect.minX, y: first.maxY, width: rect.width, height: rect.height - first.height)
    }
    return entryRectangles(Array(items[..<split]), in: first) + entryRectangles(Array(items[split...]), in: second)
}
struct MapPlacement: Identifiable { var id: UUID { node.id }; let node: ScanNode; let rect: CGRect }
enum MapLayout {
    static func rectangles(_ nodes: [ScanNode], in rect: CGRect) -> [MapPlacement] {
        entryRectangles(nodes.map { MapEntry(id: $0.id.uuidString, node: $0, name: $0.name, size: $0.logicalSize, branch: 0) }, in: rect).compactMap { item in item.entry.node.map { MapPlacement(node: $0, rect: item.rect) } }
    }
}

struct SunburstView: View {
    let nodes: [ScanNode]
    let revision: UUID
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = MapModel()
    @State private var hovered: String?
    private var active: MapEntry? { model.data.rings.first { $0.id == hovered }?.entry }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(model.data.rings) { item in
                            let shape = RingSector(start: item.start, end: item.end, depth: item.depth)
                            shape.fill(mapColors[item.entry.branch % mapColors.count].opacity(hovered == nil || hovered == item.id ? 0.86 : 0.38))
                                .overlay(shape.stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                .contentShape(shape)
                                .onHover { inside in hovered = inside ? item.id : nil }
                                .onTapGesture { if let node = item.entry.node { session.explore(node) } }
                                .help("\(item.entry.name) · \(item.entry.size.asStorageSize)")
                                .accessibilityLabel("\(item.entry.name), \(item.entry.size.asStorageSize)")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { if let node = item.entry.node { session.explore(node) } }
                        }
                        VStack(spacing: 4) {
                            Text((active?.size ?? model.data.total).asStorageSize).font(.system(size: 20, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                            Text(active?.name ?? "This folder").font(.caption2).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center)
                        }.frame(width: min(geometry.size.width, geometry.size.height) * 0.32).allowsHitTesting(false)
                    }
                }.frame(minWidth: 150)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach(model.data.entries) { item in
                            Button { if let node = item.node { session.explore(node) } } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(mapColors[item.branch % mapColors.count]).frame(width: 7, height: 7)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).lineLimit(1)
                                        Text(item.size.asStorageSize).monospacedDigit().foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }.font(.caption).padding(5).background(hovered == item.id ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).disabled(item.node == nil).onHover { hovered = $0 ? item.id : nil }
                        }
                    }
                }.frame(width: 165)
            }
            Text(active?.node?.path ?? "Each color is a folder branch. Outer rings show up to four levels; tiny items remain accessible in the list.")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle).frame(height: 30, alignment: .leading)
        }.padding(12).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
            .task(id: revision) { hovered = nil; await model.load(nodes) }
    }
}

private struct RingSector: Shape {
    let start: Double
    let end: Double
    let depth: Int
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.49
        let inner = radius * (0.38 + Double(depth) * 0.155), outer = inner + radius * 0.15
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a = Angle.radians(start * .pi * 2 - .pi / 2), b = Angle.radians(end * .pi * 2 - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: a, endAngle: b, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: b, endAngle: a, clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct BrowserRequest: Hashable {
    let root: UUID
    let revision: UUID
    let search: String
    let order: [KeyPathComparator<ScanNode>]
}

@MainActor
private final class BrowserResults: ObservableObject {
    @Published var rows: [ScanNode] = []
    @Published var distribution: [SizeDistributionBucket] = []
    @Published var loading = true
    @Published var revision = UUID()
    private let worker = IndexWorker()
    private var generation = UUID()
    func load(_ source: [ScanNode], text: String, order: [KeyPathComparator<ScanNode>]) async {
        let request = UUID(); generation = request
        loading = true
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
        let filtered = await worker.query(source, text: text, order: order)
        guard !Task.isCancelled, generation == request else { return }
        rows = filtered
        revision = request
        loading = false
        let buckets = await worker.distribution(filtered)
        guard !Task.isCancelled, generation == request else { return }
        distribution = buckets
    }
}
