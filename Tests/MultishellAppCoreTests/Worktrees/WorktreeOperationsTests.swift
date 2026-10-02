import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOperationsTests {
  private let a = "/trees/a"
  private let b = "/trees/b"

  @Test func aStageBeginsAdvancesAndFinishesOnlyWhileItIsTheOneRunning() {
    var operations = WorktreeOperations()
    operations.begin(.preDeleteHook, on: a)
    #expect(operations.isBusy(a) && !operations.isBusy(b))
    operations.advance(to: .removingWorktree, on: a)
    #expect(operations[a]?.stage == .removingWorktree)

    let otherStage = operations.finish(.postCreateHook, on: a)
    #expect(!otherStage, "another stage's ending changes nothing")
    #expect(operations[a]?.stage == .removingWorktree)
    let ownStage = operations.finish(.removingWorktree, on: a)
    #expect(ownStage)
    #expect(operations.isEmpty)
  }

  /// A post-create hook still running when a removal starts must not, on ending, clear
  /// the removal's stage or put its own failure over it.
  @Test func aRemovalTakesTheEntryFromARunningPostCreateHook() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: a)
    operations.begin(.preDeleteHook, on: a)

    let finished = operations.finish(.postCreateHook, on: a)
    let failed = operations.fail(.postCreateHook, on: a, message: "npm ERR!")
    #expect(!finished && !failed)
    #expect(operations[a] == WorktreeOperation(.preDeleteHook), "the removal's entry is untouched")
  }

  @Test func aFailureHoldsTheEntryUntilDismissedAndIgnoresLaterStages() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: a)
    let recorded = operations.fail(.postCreateHook, on: a, message: "exit 3")
    #expect(recorded)
    #expect(operations[a]?.failure == "exit 3")
    #expect(operations.isBusy(a))

    operations.advance(to: .removingWorktree, on: a)
    #expect(operations[a]?.stage == .postCreateHook, "a failed entry does not advance")
    let finished = operations.finish(.postCreateHook, on: a)
    #expect(!finished, "nor does it finish on its own")

    let dismissed = operations.dismiss(a)
    #expect(dismissed?.stage == .postCreateHook && dismissed?.failure == "exit 3")
    #expect(operations.isEmpty)
  }

  @Test func dismissLeavesARunningOperationAloneAndClearTakesAnything() {
    var operations = WorktreeOperations()
    operations.begin(.removingWorktree, on: a)
    #expect(operations.dismiss(a) == nil)
    #expect(operations.isBusy(a))
    operations.clear(a)
    #expect(operations.isEmpty)
    #expect(operations.dismiss(b) == nil, "nothing there")
  }
}
