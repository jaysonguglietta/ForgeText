import XCTest
@testable import ForgeText

final class EnterprisePlatformServiceTests: XCTestCase {
    func testContentLengthFramerHandlesFragmentedAndAdjacentMessages() throws {
        let first = Data(#"{"id":1}"#.utf8)
        let second = Data(#"{"id":2}"#.utf8)
        let framed = try ContentLengthMessageFramer.frame(first) + ContentLengthMessageFramer.frame(second)
        let split = 10
        var framer = ContentLengthMessageFramer()

        XCTAssertEqual(try framer.append(Data(framed.prefix(split))), [])
        XCTAssertEqual(try framer.append(Data(framed.dropFirst(split))), [first, second])
    }

    func testContentLengthFramerRejectsDuplicateLengthHeaders() {
        var framer = ContentLengthMessageFramer()
        let message = Data("Content-Length: 2\r\nContent-Length: 2\r\n\r\n{}".utf8)

        XCTAssertThrowsError(try framer.append(message)) { error in
            XCTAssertEqual(error as? ContentLengthMessageFramer.FramingError, .invalidContentLength)
        }
    }

    func testDevContainerNormalizerPreservesCommentMarkersAndCommasInsideStrings() throws {
        let source = #"""
        {
          // accepted JSONC comment
          "name": "value // remains,}",
          "features": {
            "example/feature:1": {},
          },
        }
        """#

        let normalized = DevContainerService.stripJSONCommentsAndTrailingCommas(source)
        let data = try XCTUnwrap(normalized.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["name"] as? String, "value // remains,}")
        XCTAssertNotNil((object["features"] as? [String: Any])?["example/feature:1"])
    }

    func testDevContainerInspectionRejectsConfigurationThatEscapesThroughSymlink() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outside = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            try? manager.removeItem(at: root)
            try? manager.removeItem(at: outside)
        }

        try Data(#"{"name":"outside"}"#.utf8).write(to: outside.appendingPathComponent("devcontainer.json"))
        try manager.createSymbolicLink(at: root.appendingPathComponent(".devcontainer"), withDestinationURL: outside)

        XCTAssertNil(DevContainerService.inspect(workspaceRoot: root))
    }

    func testEffectivePolicyCombinesManagedPolicyTrustAndSafeMode() {
        var policy = EnterpriseManagedPolicy()
        policy.features.allowLanguageServers = true
        policy.features.allowDebugAdapters = false
        let state = ManagedPolicyState(policy: policy, sourcePath: "/managed/policy.json")

        let trusted = EffectivePolicyReportService.decisions(state: state, trustMode: .trusted, safeMode: false)
        XCTAssertEqual(trusted.first(where: { $0.id == "language" })?.isAllowed, true)
        XCTAssertEqual(trusted.first(where: { $0.id == "debug" })?.isAllowed, false)

        let restricted = EffectivePolicyReportService.decisions(state: state, trustMode: .restricted, safeMode: false)
        XCTAssertTrue(restricted.allSatisfy { !$0.isAllowed })

        let safe = EffectivePolicyReportService.decisions(state: state, trustMode: .trusted, safeMode: true)
        XCTAssertTrue(safe.allSatisfy { !$0.isAllowed })
    }

    func testDocumentLifecycleReportsConflictAndRecoveryStatesInPriorityOrder() {
        var document = EditorDocument.untitled(named: "Untitled 1")
        XCTAssertEqual(document.lifecyclePhase, .untitled)

        document.isDirty = true
        XCTAssertEqual(document.lifecyclePhase, .modified)
        document.hasRecoveredDraft = true
        XCTAssertEqual(document.lifecyclePhase, .recovered)
        document.hasExternalChanges = true
        XCTAssertEqual(document.lifecyclePhase, .externallyModified)
        document.fileMissingOnDisk = true
        XCTAssertEqual(document.lifecyclePhase, .missing)
        document.isReadOnly = true
        XCTAssertEqual(document.lifecyclePhase, .readOnlyPreview)
    }

    func testGitHubRemoteConversionAcceptsOnlyGitHubOrigins() {
        XCTAssertEqual(
            GitHubWorkflowService.githubWebURL(from: "git@github.com:acme/editor.git")?.absoluteString,
            "https://github.com/acme/editor"
        )
        XCTAssertNil(GitHubWorkflowService.githubWebURL(from: "git@evil.example:acme/editor.git"))
        XCTAssertNil(GitHubWorkflowService.githubWebURL(from: "https://github.com.evil.example/acme/editor.git"))
    }

    func testShortcutValidationAndConflictDetection() {
        var bindings = ShortcutAction.defaultBindings
        bindings[.quickOpen] = bindings[.commandPalette]

        let conflicts = ShortcutAction.conflicts(in: bindings)
        XCTAssertEqual(conflicts, [.commandPalette, .quickOpen])
        XCTAssertFalse(ShortcutBinding(
            key: "x",
            usesCommand: false,
            usesShift: true,
            usesOption: false,
            usesControl: false
        ).isValid)
    }

    func testLanguageProtocolDiagnosticsAreDecodedAndBounded() throws {
        let notification: [String: Any] = [
            "method": "textDocument/publishDiagnostics",
            "params": [
                "uri": "file:///tmp/App.swift",
                "diagnostics": [[
                    "range": [
                        "start": ["line": 4, "character": 2],
                        "end": ["line": 4, "character": 8],
                    ],
                    "severity": 1,
                    "message": "Undefined symbol",
                    "source": "sourcekit-lsp",
                ]],
            ],
        ]

        let diagnostics = try XCTUnwrap(LanguageProtocolRuntimeService.diagnostics(
            serverID: "sourcekit-lsp",
            notification: notification
        ))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].range.start, LanguageTextPosition(line: 4, character: 2))
        XCTAssertEqual(diagnostics[0].message, "Undefined symbol")
        XCTAssertEqual(diagnostics[0].severity, 1)
    }
}
