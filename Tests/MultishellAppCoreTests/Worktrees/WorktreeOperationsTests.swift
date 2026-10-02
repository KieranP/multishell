import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOperationsTests {
  private let firstTree = "/trees/a"
  private let secondTree = "/trees/b"

  @Test func aStageBeginsAdvancesAndFinishesOnlyWhileItIsTheOneRunning() {
    var operations = WorktreeOperations()
    operations.begin(.preDeleteHook, on: firstTree)
    #expect(operations.isBusy(firstTree) && !operations.isBusy(secondTree))
    operations.advance(to: .removingWorktree, on: firstTree)
    #expect(operations[firstTree]?.stage == .removingWorktree)

    let otherStage = operations.finish(.postCreateHook, on: firstTree)
    #expect(!otherStage, "another stage's ending changes nothing")
    #expect(operations[firstTree]?.stage == .removingWorktree)
    let ownStage = operations.finish(.removingWorktree, on: firstTree)
    #expect(ownStage)
    #expect(operations.isEmpty)
  }

  /// A post-create hook still running when a removal starts must not, on ending, clear
  /// the removal's stage or put its own failure over it.
  @Test func aRemovalTakesTheEntryFromARunningPostCreateHook() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: firstTree)
    operations.begin(.preDeleteHook, on: firstTree)

    let finished = operations.finish(.postCreateHook, on: firstTree)
    let failed = operations.fail(.postCreateHook, on: firstTree, message: "npm ERR!")
    #expect(!finished && !failed)
    #expect(
      operations[firstTree] == WorktreeOperation(.preDeleteHook), "the removal's entry is untouched"
    )
  }

  @Test func aFailureHoldsTheEntryUntilDismissedAndIgnoresLaterStages() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: firstTree)
    let recorded = operations.fail(.postCreateHook, on: firstTree, message: "exit 3")
    #expect(recorded)
    #expect(operations[firstTree]?.failure == "exit 3")
    #expect(operations.isBusy(firstTree))

    operations.advance(to: .removingWorktree, on: firstTree)
    #expect(operations[firstTree]?.stage == .postCreateHook, "a failed entry does not advance")
    let finished = operations.finish(.postCreateHook, on: firstTree)
    #expect(!finished, "nor does it finish on its own")

    let dismissed = operations.dismiss(firstTree)
    #expect(dismissed?.stage == .postCreateHook && dismissed?.failure == "exit 3")
    #expect(operations.isEmpty)
  }

  @Test func dismissLeavesARunningOperationAloneAndClearTakesAnything() {
    var operations = WorktreeOperations()
    operations.begin(.removingWorktree, on: firstTree)
    #expect(operations.dismiss(firstTree) == nil)
    #expect(operations.isBusy(firstTree))
    operations.clear(firstTree)
    #expect(operations.isEmpty)
    #expect(operations.dismiss(secondTree) == nil, "nothing there")
  }
}
