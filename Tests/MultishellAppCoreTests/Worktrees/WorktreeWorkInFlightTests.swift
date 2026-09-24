import MultishellProcess
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeWorkInFlightTests {
  private let a = "/trees/a"
  private let b = "/trees/b"

  @Test func aStageDropsItsOwnStopHandleAndNotALaterStages() {
    var work = WorktreeWorkInFlight()
    let first = ProcessStopper()
    let second = ProcessStopper()
    work.arm(first, on: a)
    work.arm(second, on: a)

    work.end(a, stoppedBy: first)
    #expect(work.stopper(of: a) === second, "the later stage keeps its own")
    work.end(a, stoppedBy: second)
    #expect(work.stopper(of: a) == nil)
  }

  /// A removal running over a create shares the stop handle slot but owns no setup task, so its
  /// ending must leave the create's task for a caller still awaiting it.
  @Test func disarmLeavesTheSetupTaskWhereEndTakesIt() async {
    var work = WorktreeWorkInFlight()
    let stopper = ProcessStopper()
    work.arm(stopper, on: a)
    work.setSetup(Task {}, on: a)

    work.disarm(a, stoppedBy: stopper)
    #expect(work.stopper(of: a) == nil)
    #expect(work.setup(of: a) != nil, "the removal drops no create's task")

    work.end(a, stoppedBy: stopper)
    #expect(work.setup(of: a) == nil)
  }

  @Test func twoCreatesNamingOnePathEachLetGoOfTheirOwnClaim() {
    var work = WorktreeWorkInFlight()
    work.claim(a)
    work.claim(a)
    work.claim(b)
    #expect(work.isClaimed(a) && work.isClaimed(b))

    work.release(a)
    #expect(work.isClaimed(a), "the second create still holds it")
    work.release(a)
    #expect(!work.isClaimed(a))
    #expect(work.isClaimed(b))
  }

  @Test func releasingAPathNothingClaimedChangesNothing() {
    var work = WorktreeWorkInFlight()
    work.release(a)
    #expect(!work.isClaimed(a))
  }

  @Test func onlyTheCreateTheSheetIsShowingIsTheOneCancelReaches() {
    var work = WorktreeWorkInFlight()
    let first = ProcessStopper()
    let second = ProcessStopper()
    work.beginCreation(with: first)
    #expect(work.isCreating(with: first))

    work.beginCreation(with: second)
    #expect(!work.isCreating(with: first), "the older create's steps are dropped")
    #expect(work.isCreating(with: second))

    work.endCreation(with: second)
    #expect(!work.isCreating(with: second))
  }

  @Test func theFirstOfTwoCreatesToEndLeavesTheOtherItsCancel() {
    var work = WorktreeWorkInFlight()
    let first = ProcessStopper()
    let second = ProcessStopper()
    work.beginCreation(with: first)
    work.beginCreation(with: second)

    work.endCreation(with: first)
    #expect(work.isCreating(with: second))
    work.cancelCreation()
    #expect(second.isStopped)
  }
}
