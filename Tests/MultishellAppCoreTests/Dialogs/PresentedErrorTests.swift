import Foundation
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct PresentedErrorTests {
  /// The default arm prints a `LocalizedError` with `String(describing:)`, which gives the
  /// struct's fields rather than its sentence, so each one needs a case of its own.
  @Test func theGitKitErrorsReadAsSentencesRatherThanSwiftValues() {
    let branch = PresentedError(InvalidBranchName("my branch"))
    #expect(branch.message == "git will not take my branch as a branch name.")
    #expect(!branch.message.contains("InvalidBranchName"))
    #expect(!branch.title.isEmpty)

    let main = PresentedError(NotAWorktree(path: URL(fileURLWithPath: "/w/repo")))
    #expect(main.message.hasPrefix("/w/repo is the repository itself"))
    #expect(!main.message.contains("NotAWorktree"))
    #expect(!main.title.isEmpty)
  }

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

  /// Raised only once the pane that would have shown it has gone.
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

  @Test func unmovedStateNamesTheFileStillStandingThere() {
    let file = URL(fileURLWithPath: "/tmp/state.json")
    let presented = PresentedError(
      UnmovedState(
        file: file, underlying: CocoaError(.coderReadCorrupt),
        move: CocoaError(.fileWriteNoPermission)))
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("/tmp/state.json"))
    #expect(presented.message.contains("Nothing will be saved over it"))
  }

  @Test func aSettingsFileItWillNotRewriteSaysWhichAndWhatToDoInstead() {
    let file = URL(fileURLWithPath: "/Users/x/.gemini/settings.json")
    let unparsable = PresentedError(UnparsableSettingsFile(file: file))
    #expect(unparsable.title == "That settings file is not plain JSON")
    #expect(unparsable.message.contains("/Users/x/.gemini/settings.json"))
    #expect(unparsable.message.contains("comment"))
    #expect(unparsable.message.contains("Show JSON"))

    let entries = PresentedError(UnreadableHookEntries(file: file, event: "BeforeTool"))
    #expect(entries.title == "That settings file has hooks Multishell does not recognise")
    #expect(entries.message.contains("hooks.BeforeTool"))
    #expect(entries.message.contains("Show JSON"))

    let shape = PresentedError(UnexpectedSettingsShape(file: file))
    #expect(shape.title == "That settings file is not a JSON object")
    #expect(shape.message.contains("Show JSON"))
  }

  /// `MultishellProcess` depends on nothing and so has no catalogue to
  /// reach; the words for its failures live here. See translation.md.
  @Test func theProcessLayersFailuresAreTranslatedRatherThanPrintedAsWritten() {
    let noShell = PresentedError(HookFailure(stage: .preCreate, underlying: ShellUnavailable()))
    #expect(noShell.message == "No shell was found to run it with.")

    let noPipe = PresentedError(PipeUnavailable(code: EMFILE))
    #expect(noPipe.title == "A command could not be started")
    #expect(noPipe.message.hasPrefix("A pipe could not be opened:"))
    #expect(noPipe.message.contains(String(cString: strerror(EMFILE))))

    let tooLong = PresentedError(
      SocketFailure(kind: .pathTooLong, path: "/very/long/path.sock"))
    #expect(tooLong.title == "Session state reports are unavailable")
    #expect(
      tooLong.message
        == "Could not listen on the socket: the path /very/long/path.sock "
        + "is longer than a Unix socket address holds")

    let systemCall = PresentedError(
      SocketFailure(kind: .system(operation: "bind", code: EACCES), path: "/s.sock"))
    #expect(
      systemCall.message
        == "Could not listen on the socket: bind on /s.sock was refused: "
        + "\(String(cString: strerror(EACCES))) (\(EACCES))")
  }

  @Test func anotherListsSkippedEntriesAreNotNamedAsThisListsFailures() {
    let failure = WorktreeFileFailure(
      placement: .copy,
      items: [
        WorktreeFileFailure.Item(path: ".env", underlying: CocoaError(.fileWriteNoPermission))
      ]
    ).including(skipped: ["~/.aws"])
    let presented = PresentedError(failure)

    #expect(failure.items.map(\.path) == [".env"])
    #expect(presented.message.hasPrefix(".env: "))
    #expect(!presented.message.contains("~/.aws: "))
    #expect(presented.message.contains("so they were skipped and the rest placed:\n\n• ~/.aws"))
  }

  @Test func skippedListEntriesAreNamedWithWhatAnEntryMustBe() {
    let presented = PresentedError(
      WorktreeFilesSkipped(entries: ["~/.aws.json", "../shared/.env"]))

    #expect(presented.title == "Some listed files were not placed")
    #expect(presented.message.contains("~/.aws.json"))
    #expect(presented.message.contains("../shared/.env"))
    #expect(presented.message.contains("inside the repository"))
  }

  @Test func aDirectoryThatIsNotTheWorktreeSaysItWasLeftAlone() {
    let presented = PresentedError(NotTheCheckout(path: URL(fileURLWithPath: "/w/feature")))

    #expect(presented.title == "Worktree not removed: something else is at its path")
    #expect(presented.message.contains("/w/feature"))
    #expect(presented.message.contains("left it alone"))
  }

  @Test func aTrashThatTookNothingSaysSoInTheReadersLanguage() {
    let presented = PresentedError(
      TrashFailure(path: URL(fileURLWithPath: "/w/feature"), underlying: TrashTookNothing()))
    #expect(
      presented.title
        == "Worktree not removed: the directory could not be moved to the Trash or deleted")
    #expect(presented.message.contains("/w/feature"))
    #expect(presented.message.contains("The directory is still there."))
    #expect(!presented.message.contains("TrashTookNothing"))
  }

  @Test func onlyTheMissingGitAlertSaysGitIsMissing() {
    #expect(PresentedError(GitUnavailable()).saysGitIsMissing)
    #expect(!PresentedError(InvalidBranchName("x")).saysGitIsMissing)
    #expect(!PresentedError(title: "git not found", message: "").saysGitIsMissing)
  }

  @Test func retryIsAbsentUnlessAdded() {
    var presented = PresentedError(GitUnavailable())
    #expect(presented.retry == nil)
    presented.retry = .init(label: "Delete Branch Anyway") {}
    #expect(presented.retry?.label == "Delete Branch Anyway")
  }
}

/// The model has one alert slot, so what happens when several things fail at
/// once has to be decided rather than left to whichever wrote last.
@Suite @MainActor
struct SeveralFailuresAtOnceTests {
  @Test func onlyTheFirstFailedSessionTakesTheAlertAndTheRestAreLogged() {
    let h = Harness()
    h.model.select(h.main)
    for _ in 0..<3 { h.model.newTab() }
    #expect(h.model.liveTerminalCount == 4)
    h.engine.refusesToOpen = true
    for id in h.engine.openSessionIDs { h.engine.close(id) }
    h.model.presentedError = nil
    h.platform.logged.removeAll()

    h.model.reconcileSessions(takingFocus: false)

    #expect(h.model.presentedError != nil, "the user is told once")
    #expect(h.platform.logged.count == 3, "and the rest are in the log: \(h.platform.logged)")
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
struct StoppedHookPresentationTests {
  @Test func aStoppedOrTimedOutHookIsTitledForWhatEndedIt() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "installing",
      stop: .timedOut(after: .seconds(1)))
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: timedOut))
    #expect(presented.title == "Worktree created, but its hook did not finish")
    #expect(presented.message == "installing\n\nStopped after 1 second, the hook timeout.")

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stop: .stopped)
    let byUser = PresentedError(HookFailure(stage: .preCreate, underlying: stopped))
    #expect(byUser.title == "Worktree not created: its pre-create hook was stopped")
    #expect(byUser.message == "Stopped by you and printed nothing.")
  }

  @Test func theSharedSettingsQuestionShowsWhatIsAskedForAndNamesTheFile() {
    let pending = PendingSharedSettingsTrust(
      projectID: "/r", projectName: "acme", contents: "post-create:\nnpm ci\n\ncopied:\n.env",
      digest: FileDigest.sha256(of: Data()))
    #expect(pending.title == "Trust what acme's .multishell.json asks for?")
    #expect(pending.message.hasSuffix("post-create:\nnpm ci\n\ncopied:\n.env"))
    #expect(pending.trustLabel == "Trust" && pending.declineLabel == "Ignore")
  }
}
