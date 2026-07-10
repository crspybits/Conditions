//
//  Conditions2Tests.swift
//  Conditions
//
//  Created by Christopher Prince on 7/9/26.
//

import Testing
import Conditions

private actor Order {
    private(set) var values: [Int] = []
    func record(_ value: Int) { values.append(value) }
}

private actor Flag {
    private(set) var isSet = false
    func set() { isSet = true }
}

struct Condition2Tests: Sendable {
    let condition = Condition2()

    @Test func notifyWithNoWaiters() async {
        await condition.notify()
    }

    @Test func waitBlocksUntilNotified() async throws {
        let flag = Flag()

        let waiterTask = Task {
            await condition.wait()
            await flag.set()
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await flag.isSet == false)

        await condition.notify()
        _ = await waiterTask.value
        #expect(await flag.isSet == true)
    }

    // Registers 3 waiters sequentially (with delays to ensure registration order),
    // then notifies one at a time and confirms each completes before the next is woken.
    @Test func fifoOrdering() async throws {
        let order = Order()

        let task1 = Task { await condition.wait(); await order.record(1) }
        try await Task.sleep(for: .milliseconds(20))
        let task2 = Task { await condition.wait(); await order.record(2) }
        try await Task.sleep(for: .milliseconds(20))
        let task3 = Task { await condition.wait(); await order.record(3) }
        try await Task.sleep(for: .milliseconds(20))

        await condition.notify()
        _ = await task1.value
        await condition.notify()
        _ = await task2.value
        await condition.notify()
        _ = await task3.value

        let values = await order.values
        #expect(values == [1, 2, 3])
    }

    @Test func callerCancellationUnblocksWait() async throws {
        let waiterTask = Task {
            await condition.wait()
        }

        try await Task.sleep(for: .milliseconds(50))
        waiterTask.cancel()
        _ = await waiterTask.value
    }

    // Cancels a registered waiter (leaving a stale ref in the queue),
    // then verifies notify() skips it and wakes the next live waiter.
    @Test func cancelledWaiterSkippedByNotify() async throws {
        let waiterA = Task { await condition.wait() }
        try await Task.sleep(for: .milliseconds(50))
        waiterA.cancel()
        _ = await waiterA.value

        let waiterB = Task { await condition.wait() }
        try await Task.sleep(for: .milliseconds(50))

        await condition.notify()
        _ = await waiterB.value
    }
}
