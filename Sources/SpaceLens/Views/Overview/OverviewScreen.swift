import SwiftUI

struct OverviewScreen: View {
    let volume: VolumeScanResult
    @EnvironmentObject private var session: AppSession
    private var buckets: [CategoryBucket] { session.categoryBuckets }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Space to breathe.").font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("Understand your storage. Keep what matters.").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 28) {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 17)
                        Circle().trim(from: 0, to: volume.capacity.capacityUsedFraction)
                            .stroke(AngularGradient(colors: [.teal, .cyan, .blue], center: .center), style: StrokeStyle(lineWidth: 17, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text(volume.capacity.available.asStorageSize).font(.system(size: 27, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                            Text("available on disk").font(.caption).foregroundStyle(.secondary)
                        }.padding(22)
                    }.frame(width: 166, height: 166)
                    VStack(alignment: .leading, spacing: 14) {
                        Label(volume.volumeURL == NSHomeDirectory() ? "Home Folder" : volume.volumeName, systemImage: "internaldrive").font(.headline)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(volume.summary.logicalSize.asStorageSize).font(.system(size: 36, weight: .semibold, design: .rounded))
                            Text("analyzed").foregroundStyle(.secondary)
                        }
                        Text("\(volume.summary.itemCount.formatted()) items · \(volume.capacity.total.asStorageSize) disk capacity").foregroundStyle(.secondary)
                        Text(volume.volumeURL).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button { session.select(section: .storage) } label: { Label("Explore Disk Map", systemImage: "arrow.up.right") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    Spacer(minLength: 0)
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Color.teal.opacity(0.10), Color.cyan.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.teal.opacity(0.12)))

                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Where your space goes").font(.headline); Spacer(); Text("Scanned files only").font(.caption).foregroundStyle(.secondary) }
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(buckets, id: \.category) { bucket in
                                Rectangle().fill(storageColor(bucket.category)).frame(width: max(0, (geo.size.width - CGFloat(max(0, buckets.count - 1)) * 2) * CGFloat(bucket.size) / CGFloat(max(1, volume.summary.logicalSize))))
                                    .help("\(bucket.category.rawValue): \(bucket.size.asStorageSize)")
                            }
                        }.clipShape(RoundedRectangle(cornerRadius: 5))
                    }.frame(height: 16)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), alignment: .leading)], alignment: .leading, spacing: 12) {
                        ForEach(buckets.prefix(9), id: \.category) { bucket in
                            HStack(spacing: 7) {
                                Circle().fill(storageColor(bucket.category)).frame(width: 7, height: 7)
                                Text(bucket.category.rawValue).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(bucket.size.asStorageSize).monospacedDigit().foregroundStyle(.secondary)
                            }.font(.caption)
                        }
                    }
                }
                HStack { Text("Start here").font(.headline); Spacer(); Text("Review before removing").font(.caption).foregroundStyle(.secondary) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    actionCard("Large files", subtitle: "Find the files making the biggest difference.", icon: "doc.richtext", section: .largestFiles, color: .blue)
                    actionCard("Cleanup review", subtitle: "Caches, build artifacts, and downloads.", icon: "sparkles", section: .review, color: .teal)
                    actionCard("Application storage", subtitle: "See the data associated with your apps.", icon: "square.stack.3d.up", section: .appStorage, color: .orange)
                    actionCard("Old files", subtitle: "Revisit files unchanged for six months.", icon: "clock.arrow.circlepath", section: .oldFiles, color: .indigo)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Largest folders in this location").font(.headline)
                    ForEach(session.largestFolders) { node in
                        Button { session.explore(node) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill").foregroundStyle(.teal)
                                Text(node.displayName)
                                Spacer()
                                Text(node.logicalSize.asStorageSize).monospacedDigit().foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(.vertical, 10).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
                Text("Updated \(volume.scanCompletedAt.formatted(date: .abbreviated, time: .shortened)) · \(volume.accessibilityIssues.count) locations skipped")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(30)
        }
    }

    private func actionCard(_ title: String, subtitle: String, icon: String, section: WorkspaceSection, color: Color) -> some View {
        Button { session.select(section: section) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 40, height: 40).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                }
                Text(title).font(.headline)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
}

func storageColor(_ category: StorageCategory) -> Color {
    switch category {
    case .applicationBundle: .blue
    case .applicationSupport: .indigo
    case .appCache, .browserCache: .teal
    case .downloads: .cyan
    case .documents: .green
    case .media: .orange
    case .archive, .package: .yellow
    case .developer: .mint
    case .databases, .virtualMachine: .pink
    case .system, .protected: .gray
    case .logs: .brown
    case .unknown: Color(red: 0.51, green: 0.57, blue: 0.63)
    }
}

struct CleanupDashboard: View {
    let volume: VolumeScanResult
    @EnvironmentObject private var session: AppSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("A little room goes a long way.").font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Choose a category, inspect the files, then review your selection before moving anything to Trash.").font(.title3).foregroundStyle(.secondary)
                if !session.selectedNodes.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(session.selectedNodes.count) items selected").font(.headline)
                            Text(session.selectionSummary.totalLogicalSize.asStorageSize).font(.title2.monospacedDigit())
                        }
                        Spacer()
                        Button("Review Selected Items") { session.requestDeleteForSelection() }.buttonStyle(.borderedProminent).disabled(!session.canDeleteSelection)
                    }.padding(20).background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
                ForEach([WorkspaceSection.caches, .developer, .downloads, .archives, .largestFiles, .oldFiles]) { section in
                    Button { session.select(section: section) } label: {
                        HStack(spacing: 18) {
                            Image(systemName: section.icon).font(.title2).foregroundStyle(.teal).frame(width: 48, height: 48).background(Color.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(section.displayTitle).font(.headline)
                                Text(section == .caches || section == .developer ? "Review recreatable data and its impact." : "Keep what you need. Size or age does not mean disposable.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                Text(session.sectionSize(section).asStorageSize).font(.title3.weight(.medium)).monospacedDigit()
                                Text("\(session.sectionCount(section).formatted()) items").font(.caption).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Label("StorageWarden moves reviewed files to macOS Trash. Emptying Trash is a separate action.", systemImage: "checkmark.shield").font(.callout).foregroundStyle(.secondary)
            }.padding(30)
        }
    }
}
