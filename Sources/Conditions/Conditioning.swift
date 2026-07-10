//
//  Conditioning.swift
//  Conditions
//
//  Created by Christopher Prince on 7/10/26.
//

// Allow a task to wait until notified.
public protocol Conditioning {
    func wait() async
    func notify() async
}
