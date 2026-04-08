import SwiftUI

struct HTTPRequestView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let onShowRawText: () -> Void

    @State private var selectedRequestID: String?
    @State private var responseRecord: HTTPResponseRecord?
    @State private var errorMessage: String?
    @State private var isRunning = false

    private let requestDocument: HTTPRequestDocument?

    init(
        document: EditorDocument,
        theme: EditorTheme,
        onShowRawText: @escaping () -> Void
    ) {
        self.document = document
        self.theme = theme
        self.onShowRawText = onShowRawText
        requestDocument = HTTPRequestService.parse(document.text)
    }

    private var requests: [ParsedHTTPRequest] {
        requestDocument?.requests ?? []
    }

    private var selectedRequest: ParsedHTTPRequest? {
        if let selectedRequestID {
            return requests.first(where: { $0.id == selectedRequestID }) ?? requests.first
        }

        return requests.first
    }

    var body: some View {
        Group {
            if requestDocument != nil {
                VStack(spacing: 0) {
                    summaryBar
                    RetroRule()

                    HSplitView {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(requests) { request in
                                    requestCard(request)
                                }
                            }
                            .padding(16)
                        }
                        .frame(minWidth: 280)
                        .background(Color(nsColor: theme.backgroundColor))

                        VStack(spacing: 0) {
                            if let selectedRequest {
                                requestDetail(selectedRequest)
                            } else {
                                emptyResponseState
                            }
                        }
                    }
                }
                .onAppear {
                    selectedRequestID = selectedRequestID ?? requests.first?.id
                }
            } else {
                ContentUnavailableView(
                    "Couldn’t Parse HTTP Request",
                    systemImage: "network",
                    description: Text("ForgeText couldn’t find a request block in this document. Try a line like `GET https://example.com`.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
                .overlay(alignment: .bottom) {
                    Button("Open Raw Text") {
                        onShowRawText()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            Label("HTTP Runner", systemImage: "network.badge.shield.half.filled")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: theme.textColor))

            summaryPill("\(requests.count) requests")
            summaryPill(document.displayName)

            Spacer(minLength: 0)

            Button("Raw Text") {
                onShowRawText()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private func requestCard(_ request: ParsedHTTPRequest) -> some View {
        let isSelected = request.id == selectedRequest?.id

        return Button {
            selectedRequestID = request.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.name)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Text("\(request.method) \(request.urlString)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .retroPanel(fill: isSelected ? RetroPalette.chromeCyan.opacity(0.35) : RetroPalette.panelFill, accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal)
        }
        .buttonStyle(.plain)
    }

    private func requestDetail(_ request: ParsedHTTPRequest) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.name)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)
                        Text("\(request.method) \(request.urlString)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                    }

                    Spacer(minLength: 0)

                    Button(isRunning ? "Sending..." : "Send Request") {
                        run(request)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                    .disabled(isRunning)
                }

                Text(request.headers.map { "\($0.name): \($0.value)" }.joined(separator: "\n") + (request.body.isEmpty ? "" : "\n\n\(request.body)"))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
            }
            .padding(16)
            .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

            RetroRule()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let responseRecord {
                        HStack(spacing: 8) {
                            RetroCapsuleLabel(text: "\(responseRecord.statusCode) \(responseRecord.statusText)", accent: responseRecord.statusCode < 400 ? RetroPalette.success : RetroPalette.danger)
                            RetroCapsuleLabel(text: String(format: "%.2fs", responseRecord.elapsedTime), accent: RetroPalette.chromeTeal)
                        }

                        Text(responseRecord.headers.map { "\($0.name): \($0.value)" }.joined(separator: "\n"))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(responseRecord.bodyText)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.danger)
                    } else {
                        Text("Send a request to inspect the response here.")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyResponseState: some View {
        Text("Select a request to inspect and send it.")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(RetroPalette.link)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summaryPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: theme.backgroundColor).opacity(0.55))
            )
    }

    private func run(_ request: ParsedHTTPRequest) {
        isRunning = true
        errorMessage = nil

        Task {
            do {
                let response = try await HTTPRequestService.execute(request)
                await MainActor.run {
                    responseRecord = response
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    responseRecord = nil
                    isRunning = false
                }
            }
        }
    }
}
