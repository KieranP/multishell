import MultishellProcess
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeStageHandlesTests {
  private let tree = "/trees/a"

  @Test func aStageDropsItsOwnStopHandleAndNotALaterStages() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.holdStopper(first, on: tree)
    handles.holdStopper(second, on: tree)

    handles.endSetup(tree, ifStillHeldBy: first)
    #expect(handles.stopper(of: tree) === second, "the later stage keeps its own")
    handles.endSetup(tree, ifStillHeldBy: second)
    #expect(handles.stopper(of: tree) == nil)
  }

  /// A removal running over a create shares the stop handle slot but owns no setup task, so its
  /// ending must leave the create's task for a caller still awaiting it.
  @Test func releasingTheStopperLeavesTheSetupTaskWhereEndTakesIt() async {
    var handles = WorktreeStageHandles()
    let stopper = ProcessStopper()
    handles.holdStopper(stopper, on: tree)
    handles.trackSetup(Task {}, on: tree)

    handles.releaseStopper(tree, ifStillHeldBy: stopper)
    #expect(handles.stopper(of: tree) == nil)
    #expect(handles.setup(of: tree) != nil, "the removal drops no create's task")

    handles.endSetup(tree, ifStillHeldBy: stopper)
    #expect(handles.setup(of: tree) == nil)
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
    handles.stopCreation()
    #expect(second.isStopRequested)
  }
}
