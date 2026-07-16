# Conditions for Swift Concurrency actors

Straight out of the box Swift Concurrency actors do not support solutions to the readers writers problems where you'd like multiple concurrent readers. For example:

```
actor ReadersWriters {
    private var myData = [String: String]()

    func reader(access: ([String: String]) -> ()) async {
        access(myData)
    }

    func writer(set value: String, of key: String) async {
        myData[key] = value
    }
}
```

In that actor, only a single reader can be active at a time. We might like, however, to enable concurrent reader access, but only single writer access.

It is the purpose of the Condition actors provided by this package to allow for these kinds of solutions. See [the tests in this package](https://github.com/crspybits/Conditions/tree/main/Tests/ConditionsTests) for examples.

Some feedback on this package and tests are [here on Stackoverflow](https://stackoverflow.com/questions/77457078/how-to-use-actors-to-allow-parallel-reads-but-block-concurrent-reads-and-writes/77462072#comment141064729_77462072).

I've implemented three variants of Conditions. One variant is based on sleeping Task's, a second one is stream-based from the idea in https://losingfight.com/blog/2024/04/14/modeling-condition-variables-in-swift-asyncawait/, and the third one uses `withCheckedContinuation`. Initial performance tests indicate the Checked Continuation-based conditions perform better than the other two strategies. Here's a sample output from the performance test:
```
Test Suite 'Selected tests' started at 2026-07-10 16:40:14.995.
Test Suite 'ConditionsTests.xctest' started at 2026-07-10 16:40:14.995.
Test Suite 'ConditionsTests.xctest' passed at 2026-07-10 16:40:14.995.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'Selected tests' passed at 2026-07-10 16:40:14.995.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
◇ Test run started.
↳ Testing Library Version: 1501
↳ Target Platform: arm64-apple-ios13.0-simulator
◇ Suite ConditioningPerformanceTests started.
◇ Test singleWaiterThroughputComparison() started.

==== Conditioning Performance: Single-Waiter Throughput ====
Iterations measured: 50 (+ 5 warm-up, discarded)
Settle delay per iteration: 0.02 seconds (untimed; ensures waiter registration)

ContinuationCondition:   33.29 µs/op  (fastest)
StreamCondition      :   52.06 µs/op  1.56x slower
TaskCondition        :  102.26 µs/op  3.07x slower
==============================================================
✔ Test singleWaiterThroughputComparison() passed after 3.779 seconds.
✔ Suite ConditioningPerformanceTests passed after 3.779 seconds.
✔ Test run with 1 test in 1 suite passed after 3.780 seconds.
Program ended with exit code: 0
```

NOTES:
* While https://developer.apple.com/videos/play/wwdc2021/10254/ suggests conditions should not be used, the conditions in the current Swift package are not `pthread_cond` or `NSCondition` conditions and are instead implemented as actors.
