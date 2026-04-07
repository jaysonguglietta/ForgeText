import SwiftUI

struct RemoteOpenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Open Remote File")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            Text("Use a location like `user@host:/absolute/path/to/file`.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("user@host:/path/to/file", text: $appState.remoteLocationDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Remote file location")

            HStack {
                Button("Open Remote File") {
                    appState.openRemoteDocument()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            if !appState.recentRemoteLocations.isEmpty {
                Divider()

                Text("Recent Remote Locations")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                List(appState.recentRemoteLocations, id: \.spec) { reference in
                    Button {
                        appState.remoteLocationDraft = reference.spec
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reference.displayName)
                            Text(reference.pathDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(18)
        .frame(minWidth: 620, minHeight: 320)
    }
}
