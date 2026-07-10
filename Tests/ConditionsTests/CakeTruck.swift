//
//  CakeTruck.swift
//  Conditions
//
//  Created by Christopher Prince on 5/15/26.
//

import Conditions

enum ApplePieTruckError: Error {
    case noSuchOrder(Int)
}

actor CakeTruck {
    private var numberOthers = 0
    let maxPreparers = 2
    private var numberPreparers = 0
    private var pendingOrders: [Int] = []

    private var condition = TaskCondition()

    // At most 2 orders (maxPreparers) can be in preparation at one time.
    // Throws an error if the order number wasn't in the list of orders.
    func prepareOrder(orderNumber: Int) async throws {
        while numberPreparers >= maxPreparers {
            await condition.wait()
        }

        guard let index = pendingOrders.firstIndex(of: orderNumber) else {
            throw ApplePieTruckError.noSuchOrder(orderNumber)
        }

        pendingOrders.remove(at: index)

        numberPreparers += 1

        await simulatePrepWork(orderNumber)

        numberPreparers -= 1

        // In case there are waiting preparers
        await condition.notify()
    }

    private func simulatePrepWork(_ orderNumber: Int) async {
        print("Prepping order \(orderNumber)...")
        try? await Task.sleep(for: .seconds(0.1))
    }

    func placeOrder(_ orderNumber: Int) {
        pendingOrders.append(orderNumber)
    }

    func getPendingOrders() -> [Int] {
        return pendingOrders
    }
}
