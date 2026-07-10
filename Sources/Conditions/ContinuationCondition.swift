//
//  ContinuationCondition.swift
//  Conditions
//
//  Created by Christopher Prince on 7/10/26.
//

import Synchronization

// A condition backed by Swift's continuation APIs: wait() suspends via
// withCheckedContinuation, and notify() resumes the oldest still-live one.

public actor ContinuationCondition: Conditioning {
    private final class ContinuationWaiter: Sendable {
        private enum State: Sendable {
            case pending
            case installed(CheckedContinuation<Void, Never>)
            case resumed
        }

        private let state = Mutex<State>(.pending)

        // Called synchronously from wait()'s withCheckedContinuation body.
        // If this waiter was already resumed (e.g., the caller was
        // cancelled before the continuation was created), resume the
        // just-created continuation immediately instead of stranding it.
        func install(_ continuation: CheckedContinuation<Void, Never>) {
            let resumeImmediately = state.withLock { value -> Bool in
                switch value {
                case .pending:
                    value = .installed(continuation)
                    return false
                case .resumed:
                    return true
                case .installed:
                    preconditionFailure("install() called more than once")
                }
            }
            if resumeImmediately {
                continuation.resume()
            }
        }

        // Called from notify(), or from the caller's cancellation handler.
        // Returns true if this call actually woke a waiting continuation,
        // so notify() knows whether to keep looking for a live waiter.
        @discardableResult
        func resume() -> Bool {
            let continuationToResume = state.withLock { value -> CheckedContinuation<Void, Never>? in
                switch value {
                case .pending:
                    value = .resumed
                    return nil
                case .installed(let continuation):
                    value = .resumed
                    return continuation
                case .resumed:
                    return nil
                }
            }
            guard let continuationToResume else { return false }
            continuationToResume.resume()
            return true
        }
    }

    public init() {}

    private var refs = [ContinuationWaiter]()

    public func wait() async {
        let waiter = ContinuationWaiter()
        refs += [waiter]

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.install(continuation)
            }
        } onCancel: {
            waiter.resume()
        }
    }

    // Wake up one waiting task.
    public func notify() async {
        while !refs.isEmpty {
            let ref = refs.removeFirst()

            // Skip refs already resumed via cancellation — garbage collection.
            if ref.resume() {
                break
            }
        }
    }
}
