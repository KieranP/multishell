import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Testing

@testable import MultishellAppCore

/// The alert is the one place a user learns why something failed, so each
/// error type must come out with a title that names the situation and a
/// message that carries git's own words.
@Suite
struct PresentedErrorTests {
  @Test func gitFailuresShowStderrAsTheMessage() {
    let failure = ProcessFailure(
      executable: "git", arguments: ["worktree", "add", "-b", "x"], status: 128,
      message: "fatal: a branch named 'x' already exists")
    let presented = PresentedError(failure)
    #expect(presented.title == "git worktree add failed")
    #expect(presented.message == "fatal: a branch named 'x' already exists")
  }

  @Test func anEmptyStderrFallsBackToTheExitStatus() {
    let presented = PresentedError(
      ProcessFailure(executable: "git", arguments: ["status"], status: 3, message: ""))
    #expect(presented.message == "Exit status 3.")
  }

  @Test func anUnbornHEADIsExplainedInPlainWords() {
    let failure = ProcessFailure(
      executable: "git", arguments: ["worktree", "add"], status: 128,
      message: "fatal: invalid reference: HEAD")
    let presented = PresentedError(failure)
    #expect(presented.title == "This repository has no commits yet")
    #expect(presented.message.contains("first commit"))
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

  /// The alert for a file list that could not finish, which is only ever
  /// raised when the pane it belongs to has gone: it names which list it
  /// was, since a worktree may have had both.
  @Test func aFileListFailureSaysWhichListItWasAndNamesEachPath() {
    for (placement, expected) in [
      (WorktreePlacement.link, "Worktree created, but some of its files were not linked"),
      (WorktreePlacement.copy, "Worktree created, but some of its files were not copied"),
    ] {
      let presented = PresentedError(
        WorktreeFileFailure(
          placement: placement,
          items: [
            WorktreeFileFailure.Item(path: "../outside/key", underlying: WorktreeFileEscape())
          ]
        ))
      #expect(presented.title == expected)
      #expect(
        presented.message
          == "../outside/key: It leads outside the repository or the worktree.")
    }
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

  /// The app runs fetch with no terminal to answer on, so the way it fails
  /// most often is by waiting on a password prompt nobody can see.
  @Test func aFetchThatRanOutOfTimeSaysWhatToDoAboutIt() {
    let timedOut = PresentedError(
      ProcessFailure(
        executable: "git", arguments: ["fetch", "--prune", "--quiet"], status: 129, message: "",
        stop: .timedOut(after: .seconds(120))))
    #expect(timedOut.title == "Fetch did not finish")
    #expect(timedOut.message.contains("asked for a password"))
    #expect(timedOut.message.contains("SSH key"))

    let refused = PresentedError(
      ProcessFailure(
        executable: "git", arguments: ["fetch", "--prune", "--quiet"], status: 128,
        message: "fatal: could not read from remote repository"))
    #expect(refused.title == "Fetch failed")
    #expect(refused.message == "fatal: could not read from remote repository")
  }

  @Test func unreadableStateNamesTheBackupFile() {
    let backup = URL(fileURLWithPath: "/tmp/state.2026.broken.json")
    let presented = PresentedError(
      UnreadableState(backup: backup, underlying: CocoaError(.coderReadCorrupt)))
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("state.2026.broken.json"))
  }

  @Test func retryIsAbsentUnlessAdded() {
    var presented = PresentedError(GitUnavailable())
    #expect(presented.retryLabel == nil && presented.retry == nil)
    presented.retryLabel = "Delete Branch Anyway"
    #expect(presented.retryLabel == "Delete Branch Anyway")
  }
}
