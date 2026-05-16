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

It is the purpose of the Condition actor provided by this package to allow for these kinds of solutions. See the tests in this package for examples.

NOTES:
* While https://developer.apple.com/videos/play/wwdc2021/10254/ suggests conditions should not be used, the conditions in the current Swift package are not `pthread_cond` or `NSCondition` conditions and are instead implemented as actors.
