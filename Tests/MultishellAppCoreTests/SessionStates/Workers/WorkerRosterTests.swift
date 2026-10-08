import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorkerRosterTests {
  @Test func aWorkerForgottenPastTheRosterLimitTakesEveryStartUnderItsId() {
    let capacity = SessionStateReport.rosterCapacity
    var roster = WorkerRoster()
    for index in 0..<capacity {
      _ = roster.record(WorkerReport(id: "w\(index)", type: "Explore", phase: .started))
    }
    _ = roster.record(WorkerReport(id: "conversation", type: "Explore", phase: .started))
    _ = roster.record(WorkerReport(id: "conversation", type: "Explore", phase: .started))

    roster.forget("conversation")

    #expect(roster.workers.workerCount == capacity)
    #expect(roster.overflowed.isEmpty)
  }

  @Test func aToolCallNamingTheParentAfterTheStartPutsTheWorkerUnderIt() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", type: "general-purpose", phase: .started))
    roster.record(WorkerReport(id: "a1", type: "general-purpose", phase: .started))
    roster.record(
      WorkerReport(
        id: "a1", type: "general-purpose", phase: .working, parentID: "a0",
        name: "Efficiency angle"))
    roster.record(WorkerReport(id: "a1", type: "general-purpose", phase: .working))

    let worker = roster.workers.last
    #expect(worker?.parentID == "a0", "a report that does not say leaves it")
    #expect(worker?.displayName == "Efficiency angle")
    #expect(worker?.occurrences == 1)
  }

  @Test func aWorkerThatStopsWithAChildOutStaysAboveItUntilTheChildEnds() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0"))
    roster.record(WorkerReport(id: "a0", phase: .ended))

    #expect(roster.workers.nested.map(\.id) == ["a0", "a1"])
    #expect(roster.workers.nested.map(\.depth) == [0, 1])
    #expect(roster.workers.map(\.hasEnded) == [true, false])

    roster.record(WorkerReport(id: "a1", phase: .ended))
    #expect(roster.workers.isEmpty)
  }

  @Test func aStoppedWorkerHeardFromAgainIsOutAgain() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0"))
    roster.record(WorkerReport(id: "a0", phase: .ended))
    roster.record(WorkerReport(id: "a0", phase: .working))

    #expect(roster.workers.map(\.hasEnded) == [false, false])
    #expect(roster.workers.workerCount == 2)
  }

  @Test func aChildNamingAParentThatAlreadyEndedBringsThatParentBackAboveIt() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started, name: "Spawn five"))
    roster.record(WorkerReport(id: "a1", phase: .started))
    roster.record(WorkerReport(id: "a0", phase: .ended))
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0"))

    #expect(roster.workers.nested.map(\.id) == ["a0", "a1"])
    #expect(roster.workers.nested.map(\.depth) == [0, 1])
    #expect(roster.workers.first?.displayName == "Spawn five")
    #expect(roster.workers.first?.hasEnded == true)
  }

  @Test func aWorkerStopsListRemovesOnlyWorkersAnEarlierListNamed() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "f1", phase: .started))
    _ = roster.keepOnlyListedOut(
      [WorkerReport(id: "a0", phase: .working), WorkerReport(id: "b1", phase: .working)],
      stopping: nil)
    roster.record(WorkerReport(id: "a0", phase: .working, isPaused: true))
    #expect(roster.workers.map(\.id) == ["a0", "f1", "b1"], "a listed shell is out")

    let gone = roster.keepOnlyListedOut([], stopping: nil)
    #expect(gone == ["a0", "b1"])
    #expect(roster.workers.map(\.id) == ["f1"], "one no list named runs in the foreground")
  }

  @Test func aLaunchedWorkerThatLeavesTheListWithoutItsOwnStopWasKilled() {
    var roster = WorkerRoster()
    let listed = [
      WorkerReport(id: "a0", phase: .working), WorkerReport(id: "a1", phase: .working),
      WorkerReport(id: "a2", phase: .working),
      WorkerReport(id: "b1", phase: .working, isBackgroundShell: true),
    ]
    roster.recordLaunch(WorkerReport(id: "a0", phase: .started))
    roster.recordLaunch(WorkerReport(id: "a1", phase: .started))
    roster.recordLaunch(WorkerReport(id: "b1", phase: .started, isBackgroundShell: true))
    roster.record(WorkerReport(id: "a2", phase: .started))
    _ = roster.keepOnlyListedOut(listed, stopping: nil)
    roster.record(WorkerReport(id: "a1", phase: .working, isPaused: true))
    roster.record(WorkerReport(id: "a1", phase: .working))
    roster.record(WorkerReport(id: "a1", phase: .working, isPaused: true))

    _ = roster.keepOnlyListedOut([], stopping: nil)
    #expect(
      roster.workers.map(\.id) == ["a0"],
      "a1 stopped first, b1 is a shell and nothing launched a2 to say it ran apart")
    #expect(roster.workers.map(\.shownState) == [.failed])
  }

  @Test func aPausedWorkerWhoseLastShellEndsWaitsOneListForItsResume() {
    var roster = WorkerRoster()
    let shell = WorkerReport(id: "b1", phase: .working, isBackgroundShell: true)
    roster.recordLaunch(WorkerReport(id: "a0", phase: .started))
    roster.recordLaunch(
      WorkerReport(id: "b1", phase: .started, isBackgroundShell: true, parentID: "a0"))
    roster.record(WorkerReport(id: "a0", phase: .working, isPaused: true))
    _ = roster.keepOnlyListedOut([shell], stopping: nil)
    #expect(roster.workers.map(\.id) == ["a0", "b1"])

    _ = roster.keepOnlyListedOut([], stopping: nil)
    #expect(roster.workers.map(\.id) == ["a0"], "its shell's end is what wakes it")

    _ = roster.keepOnlyListedOut([], stopping: nil)
    #expect(roster.workers.isEmpty, "a list later it had not woken")
  }

  @Test func aWorkersOwnStopArrivingAfterTheListThatEndedItEndsIt() {
    var roster = WorkerRoster()
    roster.recordLaunch(WorkerReport(id: "a0", phase: .started))
    roster.recordLaunch(WorkerReport(id: "a1", phase: .started))
    _ = roster.keepOnly([], shells: [])
    #expect(roster.workers.map(\.shownState) == [.failed, .failed])

    roster.record(WorkerReport(id: "a0", phase: .working, isPaused: true))
    #expect(roster.workers.map(\.id) == ["a1"], "its stop came late, so it finished")
  }

  @Test func aWorkersOwnStopNeverPutsAWorkerBack() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "a0", phase: .ended))
    roster.record(WorkerReport(id: "a0", phase: .working, isPaused: true))
    #expect(roster.workers.isEmpty)
  }

  @Test func aKillTurnsTheWorkerAndEverythingUnderItFailed() {
    var roster = WorkerRoster()
    roster.recordLaunch(WorkerReport(id: "a0", phase: .started))
    roster.recordLaunch(WorkerReport(id: "a1", phase: .started, parentID: "a0"))
    roster.recordLaunch(
      WorkerReport(id: "b1", phase: .started, isBackgroundShell: true, parentID: "a1"))
    roster.recordLaunch(WorkerReport(id: "a2", phase: .started))
    #expect(roster.recordKill("a0") == ["a0", "a1", "b1"])
    #expect(roster.workers.map(\.shownState) == [.failed, .failed, .failed, .running])
  }

  @Test func aMainStopsListAlsoTurnsAKilledWorkerFailed() {
    var roster = WorkerRoster()
    roster.recordLaunch(WorkerReport(id: "a0", phase: .started))
    _ = roster.keepOnly([], shells: [])
    #expect(roster.workers.map(\.shownState) == [.failed])
  }

  @Test func aStopsListKeepsAStoppedParentAboveAListedChild() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0"))
    _ = roster.keepOnly([WorkerReport(id: "a1", phase: .working)], shells: [])

    #expect(roster.workers.nested.map(\.id) == ["a0", "a1"])
    #expect(roster.workers.map(\.hasEnded) == [true, false])
  }

  @Test func aShellAWorkerLaunchedKeepsItOutUntilAListLeavesTheShellOut() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.recordLaunch(
      WorkerReport(id: "b1", phase: .started, isBackgroundShell: true, parentID: "a0"))
    roster.record(WorkerReport(id: "a0", phase: .ended))
    #expect(roster.workers.nested.map(\.id) == ["a0", "b1"])

    _ = roster.keepOnlyListedOut([], stopping: nil)
    #expect(roster.workers.isEmpty)
  }

  @Test func aWorkerEndingAsFailedStaysListedUntilItIsSwept() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    roster.record(WorkerReport(id: "a1", phase: .started))
    _ = roster.keepOnlyListedOut(
      [WorkerReport(id: "a0", phase: .working), WorkerReport(id: "a1", phase: .working)],
      stopping: nil)
    _ = roster.keepOnlyListedOut([WorkerReport(id: "a1", phase: .working)], stopping: "a0")
    roster.record(WorkerReport(id: "a0", phase: .ended, hasFailed: true))

    #expect(roster.workers.map(\.shownState) == [.failed, .running])
    #expect(roster.workers.workerCount == 1, "a failed worker is not out")
    #expect(roster.hasWorkOut)

    let failedAt = Date(timeIntervalSince1970: 1_000)
    roster.stampTimes(at: failedAt)
    #expect(roster.removeFailed(before: failedAt).isEmpty)
    #expect(roster.removeFailed(before: failedAt.addingTimeInterval(1)) == ["a0"])
    #expect(roster.workers.map(\.id) == ["a1"])
  }

  @Test func aFailedWorkerAloneIsNoWorkOutAndAResumeClearsIt() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a0", phase: .started))
    _ = roster.keepOnlyListedOut([WorkerReport(id: "a0", phase: .working)], stopping: nil)
    _ = roster.keepOnlyListedOut([], stopping: "a0")
    roster.record(WorkerReport(id: "a0", phase: .ended, hasFailed: true))
    #expect(!roster.hasWorkOut)
    #expect(!roster.workers.isEmpty)
    _ = roster.keepOnly([], shells: [])
    #expect(roster.workers.map(\.id) == ["a0"], "only the sweep takes a failed row off")

    roster.record(WorkerReport(id: "a0", phase: .working))
    #expect(roster.workers.map(\.shownState) == [.running])
    #expect(roster.workers.workerCount == 1)
  }

  @Test func aWorkerFirstHeardAtAToolCallArrivesUnderItsParent() {
    var roster = WorkerRoster()
    roster.record(WorkerReport(id: "a1", phase: .working, parentID: "a0", name: "Reuse angle"))
    #expect(roster.workers.map(\.parentID) == ["a0"])
    #expect(roster.workers.map(\.displayName) == ["Reuse angle"])
  }
}
