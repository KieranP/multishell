import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct QuitGuardTests {
  @Test func workingAgentsAreCountedApartFromShells() {
    #expect(QuitGuard.message(terminals: 1, working: 0).hasPrefix("One terminal"))
    #expect(
      QuitGuard.message(terminals: 3, working: 1)
        == "3 terminals are still open and will be closed. One of them has an agent that is still working."
    )
    #expect(
      QuitGuard.message(terminals: 4, working: 2).hasSuffix(
        "2 of them have agents that are still working."))
  }
}

/// What a failed removal stage shows, for each error the coordinator throws.
@Suite
struct RemovalFailureTests {
  private let refused = ProcessFailure(
    executable: "zsh", arguments: ["-l", "-i", "-c", "exit 1"], status: 1, message: "unpushed")
  private let pruneFailed = ProcessFailure(
    executable: "git", arguments: ["worktree", "prune"], status: 128, message: "fatal: locked")

  @Test func aPreDeleteVetoKeepsTheWorktreeAndSpeaksThroughThePane() {
    let failure = RemovalFailure.describe(
      HookFailure(stage: .preDelete, underlying: refused), deletingBranch: "feat")
    #expect(failure == .vetoed(message: "unpushed\n\nExited with status 1.", timedOut: false))
  }

  @Test func aPreDeleteHookThatTimedOutIsAVetoThatSaysSoAndAStoppedOneIsNotAFailure() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "still going",
      stop: .timedOut(after: .seconds(60)))
    let failure = RemovalFailure.describe(
      HookFailure(stage: .preDelete, underlying: timedOut), deletingBranch: nil)
    #expect(
      failure
        == .vetoed(
          message: "still going\n\nStopped after 60 seconds, the hook timeout.", timedOut: true))

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stop: .stopped)
    #expect(
      RemovalFailure.describe(
        HookFailure(stage: .preDelete, underlying: stopped), deletingBranch: nil)
        == .stopped)
    let afterRemoval = RemovalFailure.describe(
      HookFailure(stage: .postDelete, underlying: stopped), deletingBranch: "feat")
    #expect(
      afterRemoval
        == .alert(
          title: "Worktree removed, but its hook was stopped",
          message: "Stopped by you and printed nothing.\n\nThe branch feat was kept.", retry: nil,
          worktreeRemoved: true), "the worktree is gone; the branch question needs an answer")
  }

  @Test func aTrashRefusalKeepsTheWorktree() {
    let error = TrashFailure(
      path: URL(fileURLWithPath: "/trees/x"),
      underlying: CocoaError(.fileWriteVolumeReadOnly))
    guard
      case .alert(let title, let message, let retry, let removed) = RemovalFailure.describe(
        error, deletingBranch: nil)
    else {
      Issue.record("expected an alert")
      return
    }
    #expect(
      title == "Worktree not removed: the directory could not be moved to the Trash or deleted")
    #expect(message.hasPrefix("/trees/x"))
    #expect(retry == nil && !removed)
  }

  @Test func aGitFailureBeforeTheDirectoryIsGoneKeepsTheWorktree() {
    let failure = RemovalFailure.describe(pruneFailed, deletingBranch: nil)
    guard case .alert(let title, let message, let retry, let removed) = failure else {
      Issue.record("expected an alert")
      return
    }
    #expect(title == "git worktree prune failed")
    #expect(message == pruneFailed.message)
    #expect(retry == nil && !removed, "the worktree and its terminals come back")
  }

  @Test func aPostDeleteFailureSaysTheBranchWasKeptOnlyWhenItWasToGo() {
    let error = HookFailure(stage: .postDelete, underlying: refused)
    let keptBranch = RemovalFailure.describe(error, deletingBranch: "feat")
    #expect(
      keptBranch
        == .alert(
          title: "Worktree removed, but its hook failed",
          message: "unpushed\n\nExited with status 1.\n\nThe branch feat was kept.", retry: nil,
          worktreeRemoved: true))
    let noBranch = RemovalFailure.describe(error, deletingBranch: nil)
    guard case .alert(_, let message, _, _) = noBranch else {
      Issue.record("expected an alert")
      return
    }
    #expect(!message.contains("was kept"))
  }

  @Test func aBranchThatWouldNotGoOffersTheForcedDelete() {
    let error = BranchDeletionFailure(
      branch: "feat",
      underlying: ProcessFailure(
        executable: "git", arguments: ["branch", "-d", "feat"], status: 1,
        message: "error: the branch 'feat' is not fully merged"))
    let failure = RemovalFailure.describe(error, deletingBranch: "feat")
    guard case .alert(let title, _, let retry, let removed) = failure else {
      Issue.record("expected an alert")
      return
    }
    #expect(title == "Worktree removed, but branch feat was not deleted")
    #expect(retry == .deleteBranchAnyway("feat"))
    #expect(retry?.label == "Force Deletion")
    #expect(removed)
  }
}

@Suite
struct PresentedMessageTests {
  @Test func eachMessageNamesWhatItIsAbout() {
    #expect(
      PresentedError.notARepository(URL(fileURLWithPath: "/w/notes")).message.hasPrefix("notes is")
    )
    #expect(PresentedError.worktreeDirectoryMissing("/w/t").message.hasPrefix("/w/t does not"))
    #expect(PresentedError.agentNotInstalled("Codex").title == "Codex is not installed")
    #expect(PresentedError.editorNotInstalled("Zed").message.contains("Install Zed"))
    #expect(PresentedError.noEditorCommand.message.contains("{path}"))
    #expect(PresentedError.themeUnreadable("bad json").message == "bad json")
  }
}

@Suite
struct DisplayNameTests {
  @Test func catalogueIdsBecomeNamesAndUnknownOnesStayAsTyped() {
    #expect(AgentCatalogue.displayName("claude") == "Claude Code")
    #expect(AgentCatalogue.displayName("custom") == "Custom command")
    #expect(AgentCatalogue.displayName("future") == "future")
    #expect(EditorCatalogue.displayName("zed") == "Zed")
    #expect(EditorCatalogue.displayName("custom") == "Custom command")
  }

  @Test func theShellNameSaysWhatTheLoginAndCustomChoicesResolveTo() {
    #expect(
      ShellCatalogue.displayName(nil, customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)")
    #expect(
      ShellCatalogue.displayName("login", customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)")
    #expect(
      ShellCatalogue.displayName("/bin/bash", customPath: "", loginShell: "/bin/zsh") == "/bin/bash"
    )
    #expect(
      ShellCatalogue.displayName("custom", customPath: " /opt/fish ", loginShell: "/bin/zsh")
        == "the custom path /opt/fish")
    #expect(
      ShellCatalogue.displayName("custom", customPath: "", loginShell: "/bin/zsh")
        == "the custom path, blank, so the login shell")
  }
}

@Suite
struct HelperLinkTests {
  @Test func refreshPointsTheLinkAtTheHelperAndReplacesAStaleOne() throws {
    let root = Scratch.path("helperlink")
    defer { try? FileManager.default.removeItem(at: root) }
    let link = root.appendingPathComponent("bin/multishell")
    let old = root.appendingPathComponent("old/multishell")
    let new = root.appendingPathComponent("new/multishell")

    try HelperLink.refresh(to: old, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == old.path)
    try HelperLink.refresh(to: new, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == new.path)
    try HelperLink.refresh(to: new, link: link)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == new.path)

    let untouched = root.appendingPathComponent("none/multishell")
    try HelperLink.refresh(to: nil, link: untouched)
    #expect(!FileManager.default.fileExists(atPath: untouched.path), "no helper, no link")
  }
}

@Suite
struct NotificationTitleTests {
  @Test func theTitlePutsTheSubjectBeforeWhereItIs() {
    #expect(
      NotificationPolicy.title(subject: "claude", project: "acme", worktree: "feat")
        == "claude · acme › feat")
  }
}
