import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellProcess

@Suite
struct PresentedErrorTests {
  /// The default arm prints a `LocalizedError` with `String(describing:)`, which gives the
  /// struct's fields rather than its sentence, so each one needs a case of its own.
  @Test func theGitKitErrorsReadAsSentencesRatherThanSwiftValues() {
    let branch = PresentedError(InvalidBranchName("my branch"))
    #expect(branch.message == "git will not take my branch as a branch name.")
    #expect(!branch.message.contains("InvalidBranchName"))
    #expect(!branch.title.isEmpty)

    let main = PresentedError(WorktreeNotRemovable(path: URL(fileURLWithPath: "/w/repo")))
    #expect(main.message.hasPrefix("/w/repo is the repository itself"))
    #expect(!main.message.contains("WorktreeNotRemovable"))
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

  /// The app runs fetch with no terminal to answer on, so the way it fails
  /// most often is by waiting on a password prompt nobody can see.
  @Test func aFetchThatRanOutOfTimeSaysWhatToDoAboutIt() {
    let timedOut = PresentedError(
      ProcessFailure(
        executable: "git", arguments: ["fetch", "--prune", "--quiet"], status: 129, message: "",
        stopReason: .timedOut(after: .seconds(120))))
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
      UnreadableStateFile(backup: backup, underlying: CocoaError(.coderReadCorrupt)))
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("state.2026.broken.json"))
  }

  @Test func unmovedStateNamesTheFileStillStandingThere() {
    let file = URL(fileURLWithPath: "/tmp/state.json")
    let presented = PresentedError(
      UnmovableStateFile(fileURL: file, underlying: CocoaError(.coderReadCorrupt)))
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

    let entries = PresentedError(UnexpectedHookEntriesShape(file: file, event: "BeforeTool"))
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
    let noDescriptor = PresentedError(DescriptorUnavailable(code: EMFILE))
    #expect(noDescriptor.title == "A command could not be started")
    #expect(noDescriptor.message.hasPrefix("The app has too many files open:"))
    #expect(noDescriptor.message.contains(String(cString: strerror(EMFILE))))

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

  @Test func aDirectoryThatIsNotTheWorktreeSaysItWasLeftAlone() {
    let presented = PresentedError(WorktreePathTaken(path: URL(fileURLWithPath: "/w/feature")))

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

  @Test func aTerminalTheEngineCouldNotStartSaysSoInWords() {
    let presented = PresentedError(TerminalUnavailable())
    #expect(presented.message == "The terminal could not be started.")
  }

  @Test func onlyTheMissingGitAlertSaysGitIsMissing() {
    #expect(PresentedError(GitUnavailable()).saysGitIsMissing)
    #expect(!PresentedError(InvalidBranchName("x")).saysGitIsMissing)
    #expect(!PresentedError(title: "git not found", message: "").saysGitIsMissing)
  }
}
