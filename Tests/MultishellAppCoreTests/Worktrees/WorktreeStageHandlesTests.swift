import MultishellProcess
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeStageHandlesTests {
  private let a = "/trees/a"

  @Test func aStageDropsItsOwnStopHandleAndNotALaterStages() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.arm(first, on: a)
    handles.arm(second, on: a)

    handles.end(a, ifStillHeldBy: first)
    #expect(handles.stopper(of: a) === second, "the later stage keeps its own")
    handles.end(a, ifStillHeldBy: second)
    #expect(handles.stopper(of: a) == nil)
  }

  /// A removal running over a create shares the stop handle slot but owns no setup task, so its
  /// ending must leave the create's task for a caller still awaiting it.
  @Test func disarmLeavesTheSetupTaskWhereEndTakesIt() async {
    var handles = WorktreeStageHandles()
    let stopper = ProcessStopper()
    handles.arm(stopper, on: a)
    handles.trackSetup(Task {}, on: a)

    handles.disarm(a, ifStillHeldBy: stopper)
    #expect(handles.stopper(of: a) == nil)
    #expect(handles.setup(of: a) != nil, "the removal drops no create's task")

    handles.end(a, ifStillHeldBy: stopper)
    #expect(handles.setup(of: a) == nil)
  }

  @Test func onlyTheCreateTheSheetIsShowingIsTheOneCancelReaches() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.beginCreation(with: first)
    #expect(handles.isCreating(with: first))

    handles.beginCreation(with: second)
    #expect(!handles.isCreating(with: first), "the older create's steps are dropped")
    #expect(handles.isCreating(with: second))

    handles.endCreation(with: second)
    #expect(!handles.isCreating(with: second))
  }

  @Test func theFirstOfTwoCreatesToEndLeavesTheOtherItsCancel() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.beginCreation(with: first)
    handles.beginCreation(with: second)

    handles.endCreation(with: first)
    #expect(handles.isCreating(with: second))
    handles.cancelCreation()
    #expect(second.isStopped)
  }
}
