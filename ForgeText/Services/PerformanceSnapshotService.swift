import Foundation

enum PerformanceSnapshotService {
    static func snapshot(
        openDocumentCount: Int,
        dirtyDocumentCount: Int,
        workspaceRootCount: Int,
        enabledPluginCount: Int,
        taskCount: Int,
        activityCount: Int,
        workspaceIndex: WorkspaceIndexSummary
    ) -> PerformanceSnapshot {
        PerformanceSnapshot(
            capturedAt: Date(),
            openDocumentCount: openDocumentCount,
            dirtyDocumentCount: dirtyDocumentCount,
            indexedFileCount: workspaceIndex.entries.count,
            indexedSymbolCount: workspaceIndex.symbols.count,
            workspaceRootCount: workspaceRootCount,
            enabledPluginCount: enabledPluginCount,
            taskCount: taskCount,
            recentActivityCount: activityCount,
            physicalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }
}
