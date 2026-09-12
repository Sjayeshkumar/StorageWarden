import SwiftUI

struct AnalysisPlaceholderScreen: View {
    let section: WorkspaceSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.rawValue)
                .font(.title2.weight(.medium))

            Text("Analytics views are now rendered through the main storage browser for this section.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Use the search bar and visualization controls in the browser panel to inspect results.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}
