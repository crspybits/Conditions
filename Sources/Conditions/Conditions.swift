//
//  Conditions.swift
//  Conditions
//
//  Created by Christopher Prince on 7/10/26.
//

public struct Conditions {
    public enum Implementation {
        case task
        case stream
    }

    public static func create(implementation: Implementation = .task) -> Conditioning {
        switch implementation {
        case .stream:
            StreamCondition()
        case .task:
            TaskCondition()
        }
    }
}
