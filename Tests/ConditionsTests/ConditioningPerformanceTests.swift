import Testing
import Conditions
import Foundation

@Suite
struct ConditioningPerformanceTests {
    // Untimed delay after spawning a waiter Task, before calling notify(),
    // to guarantee the waiter has registered itself before notify() runs
    // (notify() silently no-ops if no waiter is registered yet). Matches
    // the settle-delay convention used in ConditioningTests.swift.
    private static let settleDelay: Duration = .milliseconds(20)

    // Untimed, discarded warm-up round trips to absorb one-time costs
    // (actor executor spin-up, first AsyncStream allocation) before timing.
    private static let warmupIterations = 5

    private static let measuredIterations = 50

    private func oneRoundTrip(_ condition: Conditioning, clock: ContinuousClock) async throws -> Duration {
        let waiterTask = Task { await condition.wait() }
        try await Task.sleep(for: Self.settleDelay)

        let start = clock.now
        await condition.notify()
        _ = await waiterTask.value
        return clock.now - start
    }

    private func measureSingleWaiterThroughput(implementation: Condition.Implementation) async throws -> Duration {
        let condition = Condition.create(implementation: implementation)
        let clock = ContinuousClock()

        for _ in 0..<Self.warmupIterations {
            _ = try await oneRoundTrip(condition, clock: clock)
        }

        var total = Duration.zero
        for _ in 0..<Self.measuredIterations {
            total += try await oneRoundTrip(condition, clock: clock)
        }
        return total / Self.measuredIterations
    }

    private func microseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000_000 + Double(components.attoseconds) * 1e-12
    }

    private static let allImplementations: [(name: String, implementation: Condition.Implementation)] = [
        ("TaskCondition", .task),
        ("StreamCondition", .stream),
        ("ContinuationCondition", .continuation),
    ]

    @Test
    func singleWaiterThroughputComparison() async throws {
        var results: [(name: String, microseconds: Double)] = []
        for entry in Self.allImplementations {
            let average = try await measureSingleWaiterThroughput(implementation: entry.implementation)
            results.append((entry.name, microseconds(average)))
        }

        let sorted = results.sorted { $0.microseconds < $1.microseconds }
        let fastest = sorted[0]
        let nameWidth = (sorted.map(\.name.count).max() ?? 0)

        var lines = [
            "",
            "==== Conditioning Performance: Single-Waiter Throughput ====",
            "Iterations measured: \(Self.measuredIterations) (+ \(Self.warmupIterations) warm-up, discarded)",
            "Settle delay per iteration: \(Self.settleDelay) (untimed; ensures waiter registration)",
            "",
        ]
        for result in sorted {
            let paddedName = result.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let ratio = result.microseconds / fastest.microseconds
            let ratioText = result.name == fastest.name ? "(fastest)" : "\(String(format: "%.2f", ratio))x slower"
            lines.append("\(paddedName): \(String(format: "%7.2f", result.microseconds)) µs/op  \(ratioText)")
        }
        lines.append("==============================================================")

        print(lines.joined(separator: "\n"))
    }
}
