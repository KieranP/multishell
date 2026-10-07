import Foundation
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct PresentedErrorHookAndFileListAlertsTests {
  @Test func aStoppedOrTimedOutHookIsTitledForWhatEndedIt() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "installing",
      stopReason: .timedOut(after: .seconds(1)))
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: timedOut))
    #expect(presented.title == "Worktree created, but its hook did not finish")
    #expect(presented.message == "installing\n\nStopped after 1 second, the hook timeout.")

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stopReason: .byUser)
    let byUser = PresentedError(HookFailure(stage: .preCreate, underlying: stopped))
    #expect(byUser.title == "Worktree not created: its pre-create hook was stopped")
    #expect(byUser.message == "Stopped by you and printed nothing.")
  }

  @Test func hookFailuresSayTheWorktreeStillExists() {
    let failure = HookFailure(
      stage: .postCreate,
      underlying: ProcessFailure(
        executable: "sh", arguments: ["-c", "npm install"], status: 1, message: "npm ERR!"))
    let presented = PresentedError(failure)
    #expect(presented.title == "Worktree created, but its hook failed")
    #expect(presented.message == "npm ERR!\n\nExited with status 1.")
  }

  @Test func aSilentHookFailureGetsItsStatusNotTheCommandLineItRanAs() {
    let silent = ProcessFailure(
      executable: "zsh", arguments: ["-l", "-i", "-c", "set -e\nexit 3"], status: 3, message: "")
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: silent))
    #expect(presented.message == "Exited with status 3 and printed nothing.")
  }

  @Test func aHookThatOnlyEchoedBeforeFailingGetsItsStatusAfterItsWords() {
    let echoed = ProcessFailure(
      executable: "zsh", arguments: ["-l", "-i", "-c", "echo Created\nexit 1"], status: 1,
      message: "Created")
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: echoed))
    #expect(presented.message == "Created\n\nExited with status 1.")
  }

  @Test func preHookFailuresSayTheOperationDidNotHappen() {
    let refused = ProcessFailure(
      executable: "zsh", arguments: ["-l", "-i", "-c", "exit 1"], status: 1,
      message: "no ticket number")
    let create = PresentedError(HookFailure(stage: .preCreate, underlying: refused))
    #expect(create.title == "Worktree not created: its pre-create hook failed")
    #expect(create.message == "no ticket number\n\nExited with status 1.")
    let delete = PresentedError(HookFailure(stage: .preDelete, underlying: refused))
    #expect(delete.title == "Worktree not removed: its pre-delete hook failed")
    #expect(
      PresentedError(HookFailure(stage: .postDelete, underlying: refused)).title
        == "Worktree removed, but its hook failed")
  }

  /// Raised only once the pane that would have shown it has gone.
  @Test func aFileListFailureSaysWhichListItWasAndNamesEachPath() {
    for (placement, expected) in [
      (WorktreeFilePlacement.link, "Worktree created, but some of its files were not linked"),
      (WorktreeFilePlacement.copy, "Worktree created, but some of its files were not copied"),
    ] {
      let presented = PresentedError(
        WorktreeFileFailure(
          placement: placement,
          failures: [
            WorktreeFileFailure.PathFailure(
              path: "../outside/key", underlying: WorktreeFileEscape())
          ]
        ))
      #expect(presented.title == expected)
      #expect(
        presented.message
          == "../outside/key: It leads outside the repository or the worktree.")
    }
  }

  @Test func anotherListsSkippedEntriesAreNotNamedAsThisListsFailures() {
    let failure = WorktreeFileFailure(
      placement: .copy,
      failures: [
        WorktreeFileFailure.PathFailure(
          path: ".env", underlying: CocoaError(.fileWriteNoPermission))
      ]
    ).including(skipped: ["~/.aws"])
    let presented = PresentedError(failure)

    #expect(failure.failures.map(\.path) == [".env"])
    #expect(presented.message.hasPrefix(".env: "))
    #expect(!presented.message.contains("~/.aws: "))
    #expect(presented.message.contains("so they were skipped and the rest placed:\n\n• ~/.aws"))
  }

  @Test func skippedListEntriesAreNamedWithWhatAnEntryMustBe() {
    let presented = PresentedError(
      WorktreeFileSkipped(entries: ["~/.aws.json", "../shared/.env"]))

    #expect(presented.title == "Some listed files were not placed")
    #expect(presented.message.contains("~/.aws.json"))
    #expect(presented.message.contains("../shared/.env"))
    #expect(presented.message.contains("inside the repository"))
  }
}
