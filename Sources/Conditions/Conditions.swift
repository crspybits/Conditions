import Foundation

public actor Condition: Conditioning {
    private var refs = [Task<(), Never>]()

    public init() {}

    public func wait() async {
        let ref = Task {
            while true {
                // Int32.max is 2,147,483,647 seconds — about 68 years.
                // Using Int64.max here compiles, but fails at run time.
                try? await Task.sleep(for: .seconds(Int32.max))
                if Task.isCancelled {
                    break
                }
            }
        }
        refs += [ref]

        // Deal with the possibility that the caller was cancelled.
        await withTaskCancellationHandler {
            await ref.value
        } onCancel: {
            ref.cancel()
        }
    }


    // Wake up one waiting task.
    // Possible improvement: Could wake up *all* waiting tasks of a certain type.
    // e.g., wake up all readers in case numerous readers were waiting on a writer.
    public func notify() async {
        while !refs.isEmpty {
            let ref = refs.removeFirst()

            // The check for cancellation is to deal with waiting tasks being cancelled. i.e., it's garbage collection.
            if !ref.isCancelled {
                ref.cancel()
                break
            }
        }
    }
}
