import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  @Test func aRosterWithNoEndsStopsGrowingAtItsLimitAndStillCountsEveryWorker() {
    var states = SessionStates()
    for index in 0..<74 { _ = report(&states, .running, started("w\(index)")) }

    #expect(workersOut(states).count == 65)
    #expect(workersOut(states).first == "w0")
    #expect(states.subagents(.session(a)).workerCount == 74)
  }

  @Test func aDoneWaitsForEveryWorkerStartedPastTheRosterLimit() {
    var states = SessionStates()
    for index in 0..<70 { _ = report(&states, .running, started("w\(index)")) }
    #expect(report(&states, .done) == .running)

    for index in (1..<70).reversed() { _ = report(&states, .running, ended("w\(index)")) }
    #expect(states[.session(a)] == .running, "the oldest is still out")

    #expect(report(&states, .running, ended("w0")) == .done)
    #expect(workersOut(states).isEmpty)
  }

  @Test func aWorkerPastTheRosterLimitIsCountedOnceHoweverManyToolCallsItMakes() {
    var states = SessionStates()
    for index in 0..<70 { _ = report(&states, .running, started("w\(index)")) }
    for _ in 0..<5 { _ = report(&states, .running, working("w69")) }
    #expect(states.subagents(.session(a)).workerCount == 70)

    _ = report(&states, .done)
    for index in 0..<70 { _ = report(&states, .running, ended("w\(index)")) }
    #expect(states[.session(a)] == .done)
    #expect(workersOut(states).isEmpty)
  }

  @Test func aStrayEndPastTheRosterLimitPaysNoWorkerStillOut() {
    var states = SessionStates()
    for index in 0..<70 { _ = report(&states, .running, started("w\(index)")) }
    _ = report(&states, .done)

    _ = report(&states, .running, ended("never-started"))

    #expect(states.subagents(.session(a)).workerCount == 70)
  }

  @Test func unnamedWorkersPastTheRosterLimitAreCountedAndEndedLikeNamedOnes() {
    var states = SessionStates()
    for index in 0..<64 { _ = report(&states, .running, started("w\(index)")) }
    let unnamed = SubagentReport.anonymousID
    for _ in 0..<2 { _ = report(&states, .running, SubagentReport(id: unnamed, phase: .started)) }
    _ = report(&states, .running, SubagentReport(id: unnamed, phase: .working))
    #expect(states.subagents(.session(a)).workerCount == 66)

    for _ in 0..<2 { _ = report(&states, .running, ended(unnamed)) }
    #expect(workersOut(states) == (0..<64).map { "w\($0)" })
  }

  @Test func aWorkerForgottenPastTheRosterLimitTakesEveryStartUnderItsId() {
    var entry = SessionStates.Entry()
    for index in 0..<64 { entry.record(started("w\(index)")) }
    entry.record(started("conversation"))
    entry.record(started("conversation"))

    entry.roster.forget("conversation")

    #expect(entry.roster.subagents.workerCount == 64)
    #expect(entry.roster.overflowed.isEmpty)
  }
}
