import Foundation

enum ForgeTextRuntime {
    static let uiTestingEnvironmentKey = "FORGETEXT_UI_TESTING"

    static var isRunningUITests: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment[uiTestingEnvironmentKey] == "1"
#else
        false
#endif
    }

    static var isRunningUnitTests: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
#else
        false
#endif
    }
}
