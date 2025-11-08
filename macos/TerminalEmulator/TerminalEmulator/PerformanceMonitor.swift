import Foundation
import QuartzCore

/// Monitors and reports terminal performance metrics
class PerformanceMonitor {
    // MARK: - Metrics

    struct PerformanceMetrics {
        var fps: Double = 0
        var averageFrameTime: Double = 0  // milliseconds
        var maxFrameTime: Double = 0
        var minFrameTime: Double = Double.greatestFiniteMagnitude

        var inputLatency: Double = 0  // milliseconds
        var renderLatency: Double = 0

        var memoryUsage: UInt64 = 0  // bytes
        var cpuUsage: Double = 0  // percentage

        var totalFrames: Int = 0
        var droppedFrames: Int = 0
    }

    // MARK: - Properties

    private(set) var metrics = PerformanceMetrics()

    private var frameTimestamps: [CFTimeInterval] = []
    private let maxSamples = 60

    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [Double] = []

    var enabled: Bool = true
    var logInterval: TimeInterval = 5.0  // Log every 5 seconds

    private var lastLogTime: CFTimeInterval = 0

    // MARK: - Frame Timing

    /// Mark frame start
    func frameDidStart() {
        guard enabled else { return }

        let now = CACurrentMediaTime()

        if lastFrameTime > 0 {
            let frameTime = (now - lastFrameTime) * 1000  // Convert to ms

            frameTimes.append(frameTime)
            if frameTimes.count > maxSamples {
                frameTimes.removeFirst()
            }

            // Update metrics
            metrics.maxFrameTime = max(metrics.maxFrameTime, frameTime)
            metrics.minFrameTime = min(metrics.minFrameTime, frameTime)
            metrics.totalFrames += 1

            // Check for dropped frames (> 16.67ms = 60 FPS)
            if frameTime > 16.67 {
                metrics.droppedFrames += 1
            }
        }

        lastFrameTime = now
        frameTimestamps.append(now)

        if frameTimestamps.count > maxSamples {
            frameTimestamps.removeFirst()
        }

        // Calculate FPS
        if frameTimestamps.count >= 2 {
            let duration = frameTimestamps.last! - frameTimestamps.first!
            metrics.fps = Double(frameTimestamps.count - 1) / duration
        }

        // Calculate average frame time
        if !frameTimes.isEmpty {
            metrics.averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        }

        // Periodic logging
        if now - lastLogTime >= logInterval {
            logMetrics()
            lastLogTime = now
        }
    }

    // MARK: - Latency Measurement

    private var inputTimestamp: CFTimeInterval = 0

    /// Mark input received
    func inputReceived() {
        inputTimestamp = CACurrentMediaTime()
    }

    /// Mark input processed (rendered)
    func inputProcessed() {
        guard inputTimestamp > 0 else { return }

        let latency = (CACurrentMediaTime() - inputTimestamp) * 1000  // ms
        metrics.inputLatency = latency

        inputTimestamp = 0
    }

    // MARK: - Memory Monitoring

    func updateMemoryUsage() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            metrics.memoryUsage = taskInfo.resident_size
        }
    }

    // MARK: - CPU Monitoring

    func updateCPUUsage() {
        var threads: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        guard task_threads(mach_task_self_, &threads, &threadCount) == KERN_SUCCESS,
              let threads = threads else {
            return
        }

        var totalUsage: Double = 0

        for i in 0..<threadCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let result = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            if result == KERN_SUCCESS {
                if threadInfo.flags != TH_FLAGS_IDLE {
                    totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount))

        metrics.cpuUsage = totalUsage
    }

    // MARK: - Reporting

    func getReport() -> String {
        updateMemoryUsage()
        updateCPUUsage()

        return """
        === Performance Metrics ===
        FPS: \(String(format: "%.1f", metrics.fps))
        Avg Frame Time: \(String(format: "%.2f", metrics.averageFrameTime)) ms
        Max Frame Time: \(String(format: "%.2f", metrics.maxFrameTime)) ms
        Min Frame Time: \(String(format: "%.2f", metrics.minFrameTime)) ms
        Input Latency: \(String(format: "%.2f", metrics.inputLatency)) ms

        Total Frames: \(metrics.totalFrames)
        Dropped Frames: \(metrics.droppedFrames)

        Memory: \(ByteCountFormatter.string(fromByteCount: Int64(metrics.memoryUsage), countStyle: .memory))
        CPU: \(String(format: "%.1f", metrics.cpuUsage))%
        """
    }

    func logMetrics() {
        print(getReport())
    }

    // MARK: - Reset

    func reset() {
        metrics = PerformanceMetrics()
        frameTimestamps.removeAll()
        frameTimes.removeAll()
        lastFrameTime = 0
    }

    // MARK: - Benchmarking

    func runBenchmark(duration: TimeInterval = 10.0, completion: @escaping (PerformanceMetrics) -> Void) {
        reset()
        enabled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            completion(self.metrics)
            self.logMetrics()
        }
    }
}

// MARK: - Performance Tests

class PerformanceTests {
    /// Test rendering performance
    static func testRenderingPerformance() {
        print("Running rendering performance test...")

        let monitor = PerformanceMonitor()
        monitor.enabled = true

        // Simulate 60 FPS for 5 seconds
        let frameInterval = 1.0 / 60.0
        var frameCount = 0
        let maxFrames = 300  // 5 seconds @ 60 FPS

        func simulateFrame() {
            monitor.frameDidStart()

            frameCount += 1
            if frameCount < maxFrames {
                DispatchQueue.main.asyncAfter(deadline: .now() + frameInterval) {
                    simulateFrame()
                }
            } else {
                print(monitor.getReport())
            }
        }

        simulateFrame()
    }

    /// Test memory under load
    static func testMemoryUsage() {
        let monitor = PerformanceMonitor()

        print("Initial memory:")
        monitor.updateMemoryUsage()
        print("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(monitor.metrics.memoryUsage), countStyle: .memory))")

        // TODO: Generate load

        print("After load:")
        monitor.updateMemoryUsage()
        print("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(monitor.metrics.memoryUsage), countStyle: .memory))")
    }
}
