import Foundation

final class EditorPerformanceMonitor: @unchecked Sendable {
    static let shared = EditorPerformanceMonitor()

    private struct MetricAccumulator {
        var sampleCount = 0
        var totalDurationMS = 0.0
        var lastDurationMS = 0.0
        var maxDurationMS = 0.0
        var lastDetail: String?
        var lastPayload: String?
        var lastRecordedAt: Date?

        mutating func record(durationMS: Double, detail: String?, payload: String?) {
            sampleCount += 1
            totalDurationMS += durationMS
            lastDurationMS = durationMS
            maxDurationMS = max(maxDurationMS, durationMS)
            lastDetail = detail
            lastPayload = payload
            lastRecordedAt = Date()
        }
    }

    private let lock = NSLock()
    private var metrics: [PerformanceMetricKind: MetricAccumulator] = [:]

    private init() {}

    func record(
        _ kind: PerformanceMetricKind,
        durationMS: Double,
        detail: String? = nil,
        payload: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        var accumulator = metrics[kind] ?? MetricAccumulator()
        accumulator.record(durationMS: durationMS, detail: detail, payload: payload)
        metrics[kind] = accumulator
    }

    func measure<T>(
        _ kind: PerformanceMetricKind,
        detail: String? = nil,
        payload: String? = nil,
        operation: () -> T
    ) -> T {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let value = operation()
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
        record(kind, durationMS: elapsedMS, detail: detail, payload: payload)
        return value
    }

    func snapshot() -> [PerformanceMetricSnapshot] {
        lock.lock()
        defer { lock.unlock() }

        return PerformanceMetricKind.allCases.compactMap { kind in
            guard let metric = metrics[kind] else {
                return nil
            }

            return PerformanceMetricSnapshot(
                kind: kind,
                sampleCount: metric.sampleCount,
                lastDurationMS: metric.lastDurationMS,
                averageDurationMS: metric.sampleCount > 0 ? metric.totalDurationMS / Double(metric.sampleCount) : 0,
                maxDurationMS: metric.maxDurationMS,
                lastDetail: metric.lastDetail,
                lastPayload: metric.lastPayload,
                lastRecordedAt: metric.lastRecordedAt
            )
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        metrics.removeAll()
    }
}
