//
//  ReadersWriters.swift
//  Conditions
//
//  Created by Christopher Prince on 5/16/26.
//

import Conditions

// This is susceptible to writer starvation where there are a steady stream of readers, blocking a writer from doing its work.

actor ReadersWritersCount {
   private var numberReaders = 0
   private var writers = false

   // Writers wait on this if there are readers or writers
   // Readers wait on this if there are writers
   private var condition = Condition()

   func writerEnter() async {
       while writers || numberReaders > 0 {
           await condition.wait()
       }

       // writers is false, numberReaders == 0
       writers = true
   }

   func writerExit() async {
       writers = false
       await condition.notify()
   }

   func readerEnter() async {
       while writers {
           await condition.wait()
       }

       numberReaders += 1
   }

   func readerExit() async {
       numberReaders -= 1
       await condition.notify()
   }
}

class ReaderWriter: @unchecked Sendable {
    private var readersWritersCount = ReadersWritersCount()
    private var internalData: [String: String] = [:]

    // Other readers are still able to also use `value` concurrently.
    func value(forKey key: String) async -> String? {
        await readersWritersCount.readerEnter()
        let result = internalData[key]
        await readersWritersCount.readerExit()
        return result
    }

   // Isolated Write: Blocks other reads/writes during assignment
   func set(value: String, forKey key: String) async {
       await readersWritersCount.writerEnter()
       internalData[key] = value
       await readersWritersCount.writerExit()
   }
}

