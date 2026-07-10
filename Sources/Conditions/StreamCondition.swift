//
//  StreamCondition.swift
//  Conditions
//
//  Created by Christopher Prince on 7/9/26.
//

import Synchronization

// Modified from: https://losingfight.com/blog/2024/04/14/modeling-condition-variables-in-swift-asyncawait/

public actor StreamCondition: Conditioning {
    private final class StreamWaiter: Sendable {
        let continuation: AsyncStream<Void>.Continuation
        let waiter: @Sendable () async  -> ()
        // This is a `Mutex` to make `StreamWaiter` `Sendable`.
        let isCancelled = Mutex<Bool>(false)

        init() {
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            self.continuation = continuation
            self.waiter = {
                for await _ in stream {}
            }
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination {
                    self?.isCancelled.withLock { value in
                        value = true
                    }
                }
            }
        }
    }

    public init() {}

    private var refs = [StreamWaiter]()

    public func wait() async {
        let streamWaiter = StreamWaiter()
        refs += [streamWaiter]
        await streamWaiter.waiter()
    }

    public func notify() async {
        while !refs.isEmpty {
            let ref = refs.removeFirst()

            // The check for cancellation is to deal with waiting tasks being cancelled. i.e., it's garbage collection.
            let isCancelled = ref.isCancelled.withLock { value in
                value
            }
            if !isCancelled {
                ref.continuation.finish()
                break
            }
        }
    }
}
