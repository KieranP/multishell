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

    handles.endSetup(first, on: tree)
    #expect(handles.stopper(of: tree) === second, "the later stage keeps its own")
    handles.endSetup(second, on: tree)
    #expect(handles.stopper(of: tree) == nil)
  }

  /// A removal running over a create shares the stop handle slot but owns no setup task, so its
  /// ending must leave the create's task for a caller still awaiting it.
  @Test func releasingTheStopperLeavesTheSetupTaskWhereEndTakesIt() async {
    var handles = WorktreeStageHandles()
    let stopper = ProcessStopper()
    handles.holdStopper(stopper, on: tree)
    handles.trackSetup(Task {}, on: tree)

    handles.releaseStopper(stopper, on: tree)
    #expect(handles.stopper(of: tree) == nil)
    #expect(handles.setupTask(of: tree) != nil, "the removal drops no create's task")

    handles.endSetup(stopper, on: tree)
    #expect(handles.setupTask(of: tree) == nil)
  }

  @Test func onlyTheCreateTheSheetIsShowingIsTheOneCancelReaches() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.beginCreation(with: first)
    #expect(handles.isCurrentCreation(first))

    handles.beginCreation(with: second)
    #expect(!handles.isCurrentCreation(first), "the older create's steps are dropped")
    #expect(handles.isCurrentCreation(second))
    handles.stopCreation()
    #expect(second.isStopRequested && !first.isStopRequested)

    handles.endCreation(with: second)
    #expect(!handles.isCurrentCreation(second))
  }

  @Test func theFirstOfTwoCreatesToEndLeavesTheOtherItsCancel() {
    var handles = WorktreeStageHandles()
    let first = ProcessStopper()
    let second = ProcessStopper()
    handles.beginCreation(with: first)
    handles.beginCreation(with: second)

    handles.endCreation(with: first)
    #expect(handles.isCurrentCreation(second))
    handles.stopCreation()
    #expect(second.isStopRequested)
  }
}
