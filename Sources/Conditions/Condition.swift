//
//  Condition.swift
//  Conditions
//
//  Created by Christopher Prince on 7/10/26.
//

public struct Condition {
    public enum Implementation: Sendable {
        case task
        case stream
        case continuation
    }

    public static func create(implementation: Implementation = .continuation) -> Conditioning {
        switch implementation {
        case .stream:
            StreamCondition()
        case .task:
            TaskCondition()
        case .continuation:
            ContinuationCondition()
        }
    }
}
