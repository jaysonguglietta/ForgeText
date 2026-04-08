import SwiftUI

struct RemoteOpenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Open Remote File")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                Text("Use a location like `user@host:/absolute/path/to/file`.")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                TextField("user@host:/path/to/file", text: $appState.remoteLocationDraft)
                    .textFieldStyle(.plain)
                    .retroTextField()
                    .accessibilityLabel("Remote file location")

                HStack {
                    Button("Open Remote File") {
                        appState.openRemoteDocument()
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                if !appState.recentRemoteLocations.isEmpty {
                    RetroRule()

                    Text("Recent Remote Locations")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)

                    List(appState.recentRemoteLocations, id: \.spec) { reference in
                        Button {
                            appState.remoteLocationDraft = reference.spec
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reference.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                Text(reference.pathDescription)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RetroPalette.panelFillMuted)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(RetroPalette.panelFillMuted)
                }
            }
            .padding(18)
            .frame(minWidth: 620, minHeight: 320)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
