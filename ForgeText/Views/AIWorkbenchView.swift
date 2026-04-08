import SwiftUI

struct AIWorkbenchView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("AI Workbench", systemImage: "sparkles.rectangle.stack")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("New Chat") {
                        appState.createAISession()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                HSplitView {
                    leftRail
                        .frame(minWidth: 340)

                    rightPane
                }
            }
            .padding(14)
        }
        .frame(minWidth: 1180, minHeight: 760)
    }

    private var leftRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                providerSection
                contextSection
                sessionSection
            }
            .padding(16)
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Provider")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            if let selectedProvider = appState.selectedAIProvider {
                Picker(
                    "Provider",
                    selection: Binding(
                        get: { selectedProvider.id },
                        set: { appState.updateSelectedAIProviderID($0) }
                    )
                ) {
                    ForEach(appState.settings.aiProviders) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)

                TextField("Provider Name", text: Binding(
                    get: { appState.selectedAIProvider?.name ?? "" },
                    set: { appState.updateSelectedAIProviderName($0) }
                ))
                .textFieldStyle(.plain)
                .retroTextField()

                TextField("Base URL", text: Binding(
                    get: { appState.selectedAIProvider?.baseURLString ?? "" },
                    set: { appState.updateSelectedAIProviderBaseURL($0) }
                ))
                .textFieldStyle(.plain)
                .retroTextField()

                TextField("Model", text: Binding(
                    get: { appState.selectedAIProvider?.model ?? "" },
                    set: { appState.updateSelectedAIProviderModel($0) }
                ))
                .textFieldStyle(.plain)
                .retroTextField()

                SecureField("API Key", text: Binding(
                    get: { appState.selectedAIProvider?.apiKey ?? "" },
                    set: { appState.updateSelectedAIProviderAPIKey($0) }
                ))
                .textFieldStyle(.plain)
                .retroTextField()

                Toggle("Enabled", isOn: Binding(
                    get: { appState.selectedAIProvider?.isEnabled ?? false },
                    set: { appState.updateSelectedAIProviderEnabled($0) }
                ))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Temperature \(String(format: "%.2f", appState.selectedAIProvider?.temperature ?? 0.2))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                    Slider(
                        value: Binding(
                            get: { appState.selectedAIProvider?.temperature ?? 0.2 },
                            set: { appState.updateSelectedAIProviderTemperature($0) }
                        ),
                        in: 0...1
                    )
                }
            } else {
                Text("Enable at least one provider profile to use the AI workbench.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Context")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            Toggle("Include Selection", isOn: Binding(
                get: { appState.settings.aiIncludeSelection },
                set: {
                    appState.settings.aiIncludeSelection = $0
                    AppSettingsStore.save(appState.settings)
                }
            ))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.link)

            Toggle("Include Current File", isOn: Binding(
                get: { appState.settings.aiIncludeCurrentDocument },
                set: {
                    appState.settings.aiIncludeCurrentDocument = $0
                    AppSettingsStore.save(appState.settings)
                }
            ))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.link)

            Toggle("Include Workspace Rules", isOn: Binding(
                get: { appState.settings.aiIncludeWorkspaceRules },
                set: {
                    appState.settings.aiIncludeWorkspaceRules = $0
                    AppSettingsStore.save(appState.settings)
                }
            ))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.link)
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chats")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            if appState.aiWorkbenchState.sessions.isEmpty {
                Text("No chat sessions yet.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(appState.aiWorkbenchState.sessions) { session in
                    HStack(spacing: 8) {
                        Button {
                            appState.selectAISession(session.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.isEmpty ? "Untitled Chat" : session.title)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)

                                Text("\(session.messages.count) messages")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .retroPanel(
                                fill: appState.aiWorkbenchState.selectedSessionID == session.id ? RetroPalette.chromeCyan.opacity(0.35) : RetroPalette.panelFill,
                                accent: appState.aiWorkbenchState.selectedSessionID == session.id ? RetroPalette.chromePink : RetroPalette.chromeBlue
                            )
                        }
                        .buttonStyle(.plain)

                        Button("X") {
                            appState.deleteAISession(session.id)
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .danger))
                    }
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeGold)
    }

    private var rightPane: some View {
        VStack(spacing: 0) {
            if let statusMessage = appState.aiWorkbenchState.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }

            RetroRule()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(appState.selectedAISession?.messages ?? []) { message in
                        messageCard(message)
                    }

                    if let response = appState.aiWorkbenchState.lastResponseText,
                       appState.selectedAISession?.messages.last?.content != response {
                        messageCard(
                            AIChatMessage(
                                role: .assistant,
                                content: response,
                                providerName: appState.selectedAIProvider?.name ?? "AI",
                                model: appState.selectedAIProvider?.model ?? ""
                            )
                        )
                    }
                }
                .padding(16)
            }

            RetroRule()

            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(AIQuickAction.allCases) { action in
                            Button(action.displayName) {
                                appState.runAIQuickAction(action)
                            }
                            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                        }
                    }
                }

                TextEditor(text: Binding(
                    get: { appState.aiWorkbenchState.draftPrompt },
                    set: { appState.aiWorkbenchState.draftPrompt = $0 }
                ))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)

                HStack(spacing: 10) {
                    Button(appState.aiWorkbenchState.isSending ? "Sending..." : "Send Prompt") {
                        appState.sendAIPrompt()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                    .disabled(appState.aiWorkbenchState.isSending)

                    Button("Insert at Cursor") {
                        appState.insertLastAIResponseAtCursor()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    .disabled(appState.aiWorkbenchState.lastResponseText == nil)

                    Button("Replace Selection") {
                        appState.replaceSelectionWithLastAIResponse()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    .disabled(appState.aiWorkbenchState.lastResponseText == nil)
                }
            }
            .padding(16)
            .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromePink)
        }
    }

    private func messageCard(_ message: AIChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RetroCapsuleLabel(text: message.role.rawValue, accent: accent(for: message.role))
                Text("\(message.providerName) · \(message.model)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            Text(message.content)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(12)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent(for: message.role))
    }

    private func accent(for role: AIMessageRole) -> Color {
        switch role {
        case .system:
            return RetroPalette.chromeBlue
        case .user:
            return RetroPalette.chromeGold
        case .assistant:
            return RetroPalette.chromePink
        }
    }
}
