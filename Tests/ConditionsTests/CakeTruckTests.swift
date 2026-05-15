import Testing

import Conditions

struct CakeTruckTests {
    let truck = CakeTruck()

    @Test func prepareSingleOrder() async throws {
        await truck.placeOrder(1)
        try await truck.prepareOrder(orderNumber: 1)
        #expect(await truck.getPendingOrders().isEmpty)
    }

    @Test func prepareNonExistentOrderThrows() async throws {
        await #expect(throws: ApplePieTruckError.self) {
            try await truck.prepareOrder(orderNumber: 99)
        }
    }

    @Test func orderRemovedFromPendingList() async throws {
        await truck.placeOrder(1)
        await truck.placeOrder(2)
        await truck.placeOrder(3)
        try await truck.prepareOrder(orderNumber: 2)
        #expect(await truck.getPendingOrders() == [1, 3])
    }

    // With maxPreparers = 2, tasks 3–5 must block on condition.wait() until
    // earlier tasks finish and call condition.notify(). All 5 must complete.
    @Test func allOrdersCompleteUnderConcurrencyLimit() async throws {
        for i in 1...5 { await truck.placeOrder(i) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask { try await truck.prepareOrder(orderNumber: i) }
            }
            try await group.waitForAll()
        }

        #expect(await truck.getPendingOrders().isEmpty)
    }
}
