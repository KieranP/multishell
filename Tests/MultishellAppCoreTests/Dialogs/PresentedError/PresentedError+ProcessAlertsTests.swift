import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct PresentedErrorProcessAlertsTests {
  @Test func gitFailuresShowStderrAsTheMessage() {
    let failure = ProcessFailure(
      executable: "git",
      arguments: ["worktree", "add", "-b", "x"],
      status: 128,
      message: "fatal: a branch named 'x' already exists",
    )
    let presented = PresentedError(failure)
    #expect(presented.title == "git worktree add failed")
    #expect(presented.message == "fatal: a branch named 'x' already exists")
  }

  @Test func anEmptyStderrFallsBackToTheExitStatus() {
    let presented = PresentedError(
      ProcessFailure(executable: "git", arguments: ["status"], status: 3, message: "")
    )
    #expect(presented.message == "Exit status 3.")
  }

  @Test func anUnbornHEADIsExplainedInPlainWords() {
    let failure = ProcessFailure(
      executable: "git",
      arguments: ["worktree", "add"],
      status: 128,
      message: "fatal: invalid reference: HEAD",
    )
    let presented = PresentedError(failure)
    #expect(presented.title == "This repository has no commits yet")
    #expect(presented.message.contains("first commit"))
  }

  /// The app runs fetch with no terminal to answer on, so the way it fails
  /// most often is by waiting on a password prompt nobody can see.
  @Test func aFetchThatRanOutOfTimeSaysWhatToDoAboutIt() {
    let timedOut = PresentedError(
      ProcessFailure(
        executable: "git",
        arguments: ["fetch", "--prune", "--quiet"],
        status: 129,
        message: "",
        stopReason: .timedOut(after: .seconds(120)),
      )
    )
    #expect(timedOut.title == "Fetch did not finish")
    #expect(timedOut.message.contains("asked for a password"))
    #expect(timedOut.message.contains("SSH key"))

    let refused = PresentedError(
      ProcessFailure(
        executable: "git",
        arguments: ["fetch", "--prune", "--quiet"],
        status: 128,
        message: "fatal: could not read from remote repository",
      )
    )
    #expect(refused.title == "Fetch failed")
    #expect(refused.message == "fatal: could not read from remote repository")
  }

  /// `MultishellProcess` depends on nothing and so has no catalogue to
  /// reach; the words for its failures live here. See translation.md.
  @Test func theProcessLayersFailuresAreTranslatedRatherThanPrintedAsWritten() {
    let noDescriptor = PresentedError(DescriptorUnavailable(code: EMFILE))
    #expect(noDescriptor.title == "A command could not be started")
    #expect(noDescriptor.message.hasPrefix("The app has too many files open:"))
    #expect(noDescriptor.message.contains(String(cString: strerror(EMFILE))))

    let tooLong = PresentedError(
      SocketFailure(kind: .pathTooLong, path: "/very/long/path.sock")
    )
    #expect(tooLong.title == "Session state reports are unavailable")
    #expect(
      tooLong.message
        == "Could not listen on the socket: the path /very/long/path.sock "
        + "is longer than a Unix socket address holds"
    )

    let systemCall = PresentedError(
      SocketFailure(kind: .system(operation: "bind", code: EACCES), path: "/s.sock")
    )
    #expect(
      systemCall.message
        == "Could not listen on the socket: bind on /s.sock was refused: "
        + "\(String(cString: strerror(EACCES))) (\(EACCES))"
    )
  }
}
