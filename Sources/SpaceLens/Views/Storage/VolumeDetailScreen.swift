import SwiftUI

struct VolumeDetailScreen: View {
    let volumeID: UUID
    @ObservedObject var session: AppSession

    var body: some View {
        if let volume = session.volumes.first(where: { $0.id == volumeID }) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(volume.volumeName)
                        .font(.headline)
                    Text(volume.volumeURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(volume.capacity.used.asStorageSize)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text((volume.capacity.total - volume.capacity.used).asStorageSize)
                        .font(.subheadline.weight(.medium))
                }

                ProgressView(value: volume.capacity.capacityUsedFraction)
                    .tint(.accentColor)

                Text("Items: \(volume.summary.itemCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Text("Selected volume is no longer available.")
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }
}
