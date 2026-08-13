import XCTest
@testable import ForgeText

final class CommandExecutionServiceTests: XCTestCase {
    func testExecuteDrainsLargeStdoutWithoutBlocking() throws {
        let result = try CommandExecutionService.execute(
            "/bin/dd",
            arguments: ["if=/dev/zero", "bs=65536", "count=2"]
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.stdout.count, 131_072)
    }

    func testExecuteCapsOutputWhileContinuingToDrainProcessPipes() throws {
        let output = String(repeating: "x", count: 4_096)
        let limits = CommandExecutionService.ExecutionLimits(
            timeout: 2,
            maxStandardOutputBytes: 64,
            maxStandardErrorBytes: 64,
            maxStandardInputBytes: 64
        )

        let result = try CommandExecutionService.execute(
            "/usr/bin/printf",
            arguments: ["%s", output],
            limits: limits
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.stdout.count, 64)
        XCTAssertTrue(result.stdoutWasTruncated)
    }

    func testExecuteTerminatesCommandsThatExceedTimeLimit() {
        let limits = CommandExecutionService.ExecutionLimits(
            timeout: 0.05,
            maxStandardOutputBytes: 64,
            maxStandardErrorBytes: 64,
            maxStandardInputBytes: 64
        )

        XCTAssertThrowsError(
            try CommandExecutionService.execute(
                "/bin/sleep",
                arguments: ["2"],
                limits: limits
            )
        ) { error in
            guard case CommandExecutionService.ExecutionError.timedOut = error else {
                return XCTFail("Expected a timeout, received \(error)")
            }
        }
    }

    func testExecuteRejectsOversizedStandardInputBeforeLaunch() {
        let limits = CommandExecutionService.ExecutionLimits(
            timeout: 2,
            maxStandardOutputBytes: 64,
            maxStandardErrorBytes: 64,
            maxStandardInputBytes: 4
        )

        XCTAssertThrowsError(
            try CommandExecutionService.execute(
                "/bin/cat",
                arguments: [],
                input: Data(repeating: 0x41, count: 5),
                limits: limits
            )
        ) { error in
            guard case CommandExecutionService.ExecutionError.inputTooLarge = error else {
                return XCTFail("Expected an input-size error, received \(error)")
            }
        }
    }
}
