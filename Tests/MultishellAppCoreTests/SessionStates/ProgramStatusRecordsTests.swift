import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ProgramStatusRecordsTests {
  @Test func aChildRecordsFinishLeavesTheDotToTheProgramsOwn() {
    var records = ProgramStatusRecords()
    records.record(.init(state: .done), from: nil, at: Date())
    records.record(.init(state: .failed, recordID: "deploy/eu"), from: nil, at: Date())

    #expect(records.shownState == .done)
  }

  @Test func aClearTakesTheRecordAndTheRecordsUnderItButNotASiblingSharingItsPrefix() {
    var records = ProgramStatusRecords()
    records.record(.init(state: .idle), from: nil, at: Date())
    records.record(.init(state: .working, recordID: "deploy/us"), from: nil, at: Date())
    records.record(.init(state: .working, recordID: "deployment"), from: nil, at: Date())

    records.record(.init(state: .clear, recordID: "deploy"), from: nil, at: Date())
    #expect(records.shownState == .running, "deployment is still out")

    records.record(.init(state: .clear, recordID: "deployment"), from: nil, at: Date())
    #expect(records.shownState == .idle)
  }

  @Test func childRecordsPastTheRosterCapacityAreDroppedAndKnownOnesStillUpdate() {
    var records = ProgramStatusRecords()
    for index in 0..<SessionStateReport.rosterCapacity {
      records.record(.init(state: .working, recordID: "task\(index)"), from: nil, at: Date())
    }

    records.record(.init(state: .blocked, recordID: "late"), from: nil, at: Date())
    #expect(records.shownState == .running)

    records.record(.init(state: .blocked, recordID: "task0"), from: nil, at: Date())
    #expect(records.shownState == .attention)
  }

  @Test func finishedChildRecordsTakeNoPlaceFromOneThatAsksLater() {
    var records = ProgramStatusRecords()
    records.record(.init(state: .working), from: nil, at: Date())
    for index in 0..<SessionStateReport.rosterCapacity {
      records.record(.init(state: .done, recordID: "job\(index)"), from: nil, at: Date())
    }

    records.record(.init(state: .blocked, recordID: "late"), from: nil, at: Date())

    #expect(records.shownState == .attention)
  }
}
