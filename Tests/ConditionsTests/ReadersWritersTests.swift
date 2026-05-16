//
//  ReadersWritersTests.swift
//  Conditions
//
//  Created by Christopher Prince on 5/16/26.
//

import Foundation
import Testing
import Conditions

private actor Order {
    private(set) var values: Set<Int> = []
    func record(_ value: Int) { values.insert(value) }
}

private actor Flag {
    private(set) var isSet = false
    func set() { isSet = true }
}

private actor EventLog {
    private(set) var events: [String] = []
    func log(_ event: String) { events.append(event) }
}

struct ReadersWritersTests {
    @Test func writerWaitsForConcurrentReaders() async {
        let readerWriter = ReaderWriter()
        let completion = Order()

        let task1 = Task {
            await readerWriter.readOnlyAccess { dictionary in
                print("Task1: Start: Sleep")
                try? await Task.sleep(for: .seconds(1))
                print("Task1: End: Sleep")
                await completion.record(1)
            }
        }

        let task2 = Task {
            await readerWriter.readOnlyAccess { dictionary in
                print("Task2: Start: Sleep")
                try? await Task.sleep(for: .seconds(1))
                print("Task2: End: Sleep")
                await completion.record(2)
            }
        }

        // Allow the first two tasks to start.
        try? await Task.sleep(for: .milliseconds(50))

        let task3 = Task {
            await readerWriter.set(value: "foo", forKey: "bar")
            #expect(await completion.values == [1, 2])
        }

        await task1.value
        await task2.value
        await task3.value
        print("Test: End")
    }

    @Test func writerWaitsForReader() async throws {
        let rwc = ReadersWritersCount()
        let flag = Flag()

        await rwc.readerEnter()

        let writerTask = Task {
            await rwc.writerEnter()
            await flag.set()
            await rwc.writerExit()
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await flag.isSet == false)

        await rwc.readerExit()
        await writerTask.value
        #expect(await flag.isSet == true)
    }

    @Test func readerWaitsForWriter() async throws {
        let rwc = ReadersWritersCount()
        let flag = Flag()

        await rwc.writerEnter()

        let readerTask = Task {
            await rwc.readerEnter()
            await flag.set()
            await rwc.readerExit()
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await flag.isSet == false)

        await rwc.writerExit()
        await readerTask.value
        #expect(await flag.isSet == true)
    }

    @Test func writersAreMutuallyExclusive() async throws {
        let rwc = ReadersWritersCount()
        let log = EventLog()

        let taskA = Task {
            await rwc.writerEnter()
            await log.log("A-entered")
            try? await Task.sleep(for: .milliseconds(100))
            await log.log("A-exited")
            await rwc.writerExit()
        }

        try await Task.sleep(for: .milliseconds(10))

        let taskB = Task {
            await rwc.writerEnter()
            await log.log("B-entered")
            await rwc.writerExit()
        }

        await taskA.value
        await taskB.value

        let events = await log.events
        let aExitIndex = try #require(events.firstIndex(of: "A-exited"))
        let bEnterIndex = try #require(events.firstIndex(of: "B-entered"))
        #expect(aExitIndex < bEnterIndex)
    }
}
