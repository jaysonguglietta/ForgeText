import XCTest
@testable import ForgeText

final class WorkbenchPresetTests: XCTestCase {
    func testMatchingPresetRecognizesBuiltInSnapshots() {
        XCTAssertEqual(WorkbenchPreset.matching(WorkbenchPreset.quiet.appearance), .quiet)
        XCTAssertEqual(WorkbenchPreset.matching(WorkbenchPreset.balanced.appearance), .balanced)
        XCTAssertEqual(WorkbenchPreset.matching(WorkbenchPreset.fullRetro.appearance), .fullRetro)
    }

    func testSyncWorkbenchPresetFromCurrentSettingsMarksCustomState() {
        var settings = AppSettings()
        settings.chromeStyle = .retroPro
        settings.interfaceDensity = .compact
        settings.focusModeEnabled = false
        settings.showsInspector = true
        settings.showsBreadcrumbs = false

        settings.syncWorkbenchPresetFromCurrentSettings()

        XCTAssertNil(settings.workbenchPreset)
        XCTAssertEqual(
            settings.customWorkbenchAppearance,
            WorkbenchAppearanceSnapshot(
                chromeStyle: .retroPro,
                interfaceDensity: .compact,
                focusModeEnabled: false,
                showsInspector: true,
                showsBreadcrumbs: false
            )
        )
    }
}
