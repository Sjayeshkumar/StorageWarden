import AppKit
import QuickLook
import SwiftUI

struct InspectorView: View {
    let volume: VolumeScanResult

    @EnvironmentObject private var session: AppSession
    @State private var previewURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if session.selectedNodes.count > 1 {
                    multiPanel
                } else if let selected = session.selectedNodes.first {
                    selectedPanel(selected)
                } else {
                    idlePanel
                }

            }
            .padding(12)
        }
        .background(.thinMaterial)
        .quickLookPreview($previewURL)
    }

    private var idlePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Selection")
                .font(.headline)
            Text("Select any item in the table to view details and cleanup guidance.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var multiPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selection summary")
                .font(.headline)

            inspectorRow("Items", String(session.selectionSummary.count))
            inspectorRow("Total logical", session.selectionSummary.totalLogicalSize.asStorageSize)
            inspectorRow("Allocated", session.selectionSummary.totalAllocatedSize.asStorageSize)
            inspectorRow("Low risk", session.selectionSummary.lowRiskLogical.asStorageSize)
            inspectorRow("Review", session.selectionSummary.reviewLogical.asStorageSize)
            inspectorRow("Important", session.selectionSummary.importantLogical.asStorageSize)
            inspectorRow("Protected", session.selectionSummary.protectedLogical.asStorageSize)

            Button("Review for Trash") {
                session.requestDeleteForSelection()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canDeleteSelection)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func selectedPanel(_ node: ScanNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.displayName)
                .font(.headline)
                .lineLimit(2)
            Text(node.logicalSize.asStorageSize)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text(node.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            inspectorSection(title: "Storage") {
                inspectorRow("Logical", node.aggregatedLogicalSize.asStorageSize)
                inspectorRow("On disk", node.aggregatedAllocatedSize.asStorageSize)
                inspectorRow("Type", node.fileType.isEmpty ? (node.isDirectory ? "Directory" : "File") : node.fileType)
                inspectorRow("Category", node.classification.category.rawValue)
                inspectorRow("Items", "\(node.itemCount)")
            }

            inspectorSection(title: "Safety") {
                inspectorRow("Importance", node.classification.importance.rawValue)
                inspectorRow("Cleanup risk", node.classification.cleanupRisk.rawValue)
                inspectorRow("Confidence", node.classification.confidence.rawValue)
                inspectorRow("Re-creatable", node.classification.canBeRecreated ? "Yes" : "No")
                if let app = node.classification.associatedApplication {
                    inspectorRow("Associated app", app)
                }
                if let mod = node.modifiedAt {
                    inspectorRow("Modified", mod.formatted(date: .abbreviated, time: .shortened))
                }
                if let opened = node.lastOpenedAt {
                    inspectorRow("Last accessed", opened.formatted(date: .abbreviated, time: .shortened))
                }
                if let created = node.createdAt {
                    inspectorRow("Created", created.formatted(date: .abbreviated, time: .shortened))
                }
            }

            inspectorSection(title: "What is this?") {
                Text(node.classification.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("What happens if removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Text(node.classification.deletionConsequences)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Button("Reveal") {
                    session.openNodeInFinder(node)
                }
                .buttonStyle(.bordered)

                Button("Quick Look") {
                    previewURL = node.url
                }
                .buttonStyle(.bordered)

                if session.canDelete(node: node) {
                    Button("Move to Trash") {
                        session.deleteNode(node)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if !session.canDelete(node: node) {
                Text(node.isDirectory ? "For safety, folders and app bundles cannot be moved here. Open this folder and review individual files, or use Finder." : node.fileIdentity == nil ? "Rescan this folder before cleanup. This older result has no file identity check." : "Delete blocked: \(node.classification.defaultAction)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent cleanup")
                .font(.headline)

            if session.trashHistory.isEmpty {
                Text("No entries in this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.trashHistory.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.path)
                            .lineLimit(1)
                            .font(.caption)
                        HStack {
                            Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                            Text(item.success ? "Moved" : "Failed")
                                .foregroundStyle(item.success ? .green : .red)
                        }
                        .font(.caption2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func inspectorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(.top, 6)
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct DeletionReviewSheet: View {
    @EnvironmentObject private var session: AppSession
    @State private var reviewed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let preview = session.currentDeletionPreview {
                VStack(alignment: .leading, spacing: 12) {
                    Text(preview.title)
                        .font(.title3.weight(.semibold))
                    Text("Logical size: \(preview.totalLogicalSize.asStorageSize)")
                        .foregroundStyle(.secondary)
                    Text("On disk: \(preview.totalAllocatedSize.asStorageSize)")
                        .foregroundStyle(.secondary)

                    if !preview.items.isEmpty {
                        Text("Items")
                            .font(.headline)
                        List(preview.items) { item in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(item.displayName).fontWeight(.semibold).lineLimit(1)
                                    Spacer()
                                    Text(item.aggregatedLogicalSize.asStorageSize).monospacedDigit()
                                }
                                Text(item.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                Text(item.classification.cleanupRisk.rawValue + " · " + item.classification.confidence.rawValue + " confidence").font(.caption.weight(.medium))
                                Text(item.classification.deletionConsequences).font(.caption).foregroundStyle(.secondary)
                                Button("Reveal in Finder") { session.openNodeInFinder(item) }.controlSize(.small)
                            }.padding(.vertical, 8)
                        }
                    }

                    Toggle("I have reviewed these files and the impact of removing them.", isOn: $reviewed)
                    Text("Files are placed in private StorageWarden folders inside Trash. Restore them by dragging them out in Finder; automatic Put Back is not provided. Cross-drive moves are blocked. Nothing is permanently deleted.").font(.caption).foregroundStyle(.secondary)

                    if let error = session.deletionError {
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("Cancel") {
                            session.closeDeletionSheet()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Move to Trash") {
                            session.confirmDeletion()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!reviewed || session.isDeleting)
                    }
                }
            } else {
                Text("No items selected")
                Button("Close") {
                    session.closeDeletionSheet()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 600, height: 560)
    }
}
