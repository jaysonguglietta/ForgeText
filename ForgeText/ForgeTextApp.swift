import SwiftUI

@main
struct ForgeTextApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
    @StateObject private var appUpdateController = AppUpdateController()

    var body: some Scene {
        WindowGroup("ForgeText") {
            ContentView(appState: applicationDelegate.appState)
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    applicationDelegate.appState.processLaunchArgumentsIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    CrashRecoveryMonitor.markCleanExit()
                }
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            UpdateCommands(updateController: appUpdateController)
            FileEditorCommands(appState: applicationDelegate.appState)
            AIWorkbenchCommands(appState: applicationDelegate.appState)
            TextEditingCommands()
        }
    }
}
