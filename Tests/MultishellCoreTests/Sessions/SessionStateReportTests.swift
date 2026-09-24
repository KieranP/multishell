import Foundation
import Testing

@testable import MultishellCore

/// The socket is a file any process of the user's can write to, so every
/// odd line here must cost that line only.
@Suite
struct SessionStateReportTests {
  @Test func aFullReportRoundTrips() throws {
    let id = UUID()
    let report = SessionStateReport(
      state: .attention, sessionID: id, cwd: "/w/repo", pid: 4242, message: "Needs permission",
      duration: 12.5, agent: "claude", silent: true)
    let line = try report.encodedLine()
    #expect(line.hasSuffix("\n"))
    #expect(!line.dropLast().contains("\n"), "one line per message")
    #expect(SessionStateReport.parse(line) == report)
  }

  @Test func everyStringOffTheChannelIsBounded() {
    let long = String(repeating: "x", count: 12_000)
    let shells = (1...500).map(String.init).joined(separator: ",")
    let line = """
      {"state":"running","agent":"\(long)","cwd":"/\(long)","command":"\(long) arg",\
      "subagent":{"id":"\(long)","type":"\(long)","phase":"started"},\
      "shells":[\(shells)]}
      """
    let report = SessionStateReport.parse(line)

    #expect(report?.agent == nil)
    #expect(report?.cwd == nil)
    #expect(report?.command == nil)
    #expect(report?.subagent?.id == SubagentReport.anonymousID)
    #expect(report?.subagent?.type?.count == SubagentReport.maximumTypeLength + 1)
    #expect(report?.backgroundShells?.count == SessionStateReport.rosterLimit)
  }

  @Test func boundedStringsWithinTheirLimitsAreKeptWhole() {
    let report = SessionStateReport.parse(
      #"{"state":"running","agent":"codex","cwd":"/w/repo","command":"/bin/make all","#
        + #""subagent":{"id":"t1","type":"Explore","phase":"working"}}"#)

    #expect(report?.agent == "codex")
    #expect(report?.cwd == "/w/repo")
    #expect(report?.command == "make")
    #expect(report?.subagent == SubagentReport(id: "t1", type: "Explore", phase: .working))
  }

  @Test func onlyTheStateIsRequiredAndTheVersionDefaultsToOne() {
    let report = SessionStateReport.parse(#"{"state":"running"}"#)
    #expect(report?.state == .running)
    #expect(report?.version == 1)
    #expect(report?.sessionID == nil && report?.cwd == nil && report?.pid == nil)
    #expect(report?.duration == nil)
    #expect(report?.agent == nil, "an older helper names no agent and still reports")
    #expect(report?.silent == nil, "absent is the usual: the report raises its banner")
  }

  /// The dot moves on the first of the two reports a permission prompt
  /// makes, and the banner waits for the second.
  @Test func aSilentReportIsCarriedAndKeepsItsBannerBack() throws {
    let silent = SessionStateReport(state: .attention, silent: true)
    #expect(try silent.encodedLine().contains("\"silent\":true"))
    #expect(SessionStateReport.parse(try silent.encodedLine())?.silent == true)
    #expect(!(try SessionStateReport(state: .attention).encodedLine().contains("silent")))
  }

  @Test func aNewerHelperWithFieldsThisBuildDoesNotKnowStillParses() {
    let report = SessionStateReport.parse(
      #"{"v":7,"state":"done","session":"\#(UUID().uuidString)","colour":"amber"}"#)
    #expect(report?.state == .done)
    #expect(report?.version == 7)
  }

  @Test(arguments: [
    "", "   ", "not json", "[1,2]", "{}", #"{"state":"sleeping"}"#, #"{"state":3}"#,
    #"{"state":"running","session":"not-a-uuid"}"#, #"{"state":"running","pid":"abc"}"#,
    "{\"state\":\"running\"", "\u{0}",
  ])
  func aMalformedLineIsDroppedNotCrashedOn(line: String) {
    #expect(SessionStateReport.parse(line) == nil)
  }

  @Test func theMostUrgentStateWinsAndIdleIsNothing() {
    #expect(SessionState.mostUrgent([.done, .attention, .running]) == .attention)
    #expect(SessionState.mostUrgent([.done, .running]) == .running)
    #expect(SessionState.mostUrgent([.running, .error]) == .error, "a failure outranks work")
    #expect(
      SessionState.mostUrgent([.attention, .error]) == .error,
      "and a question: a row with a failed tab is red whatever the others ask")
    #expect(SessionState.mostUrgent([.idle, .done]) == .done, "one finished tab is enough")
    #expect(SessionState.mostUrgent([.idle, .idle]) == nil, "idle only when every tab is")
    #expect(SessionState.mostUrgent([.idle]) == nil)
    #expect(SessionState.mostUrgent([]) == nil)
    #expect(SessionState.idle.stored == nil)
    #expect(SessionState.done.stored == .done)
  }

  @Test func eachNotifiedStateIsAskedForOnItsOwnAndRunningNeverBanners() {
    let all = NotificationPreference(attention: true, error: true, done: true)
    #expect(!all[.running], "a banner per tool call would be noise")
    #expect(!all[.idle])
    #expect(NotificationPreference.notifiableStates == [.attention, .error, .done])

    for state in NotificationPreference.notifiableStates {
      var one = NotificationPreference.off
      one[state] = true
      #expect(one[state], "\(state)")
      for other in NotificationPreference.notifiableStates where other != state {
        #expect(!one[other], "\(state) does not turn on \(other)")
      }
    }
    #expect(NotificationPreference.notifiableStates.allSatisfy { !NotificationPreference.off[$0] })
  }

  @Test func exitCodesBecomeDoneOrFailedAndSignalsAreNotFailures() {
    #expect(SessionState.finished(exitCode: 0) == .done)
    #expect(SessionState.finished(exitCode: nil) == .done)
    #expect(SessionState.finished(exitCode: 1) == .error)
    #expect(SessionState.finished(exitCode: 127) == .error)
    #expect(SessionState.finished(exitCode: 130) == .done, "Ctrl+C is the user's own doing")
    #expect(SessionState.error.isFinished && SessionState.done.isFinished)
    #expect(!SessionState.running.isFinished)
  }

  @Test func theEnvironmentNamesTheSessionTheWorktreeAndTheSocket() {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w/repo"), title: "Shell")
    let variables = SessionEnvironment.variables(
      for: session, socket: URL(fileURLWithPath: "/state/multishell.sock"))
    #expect(variables["MULTISHELL_SESSION"] == session.id.uuidString)
    #expect(variables["MULTISHELL_WORKTREE"] == "/w/repo")
    #expect(variables["MULTISHELL_SOCKET"] == "/state/multishell.sock")
    #expect(
      variables["MULTISHELL_APP_PID"] == String(ProcessInfo.processInfo.processIdentifier),
      "so the helper's walk up from a prompt knows where to stop")
  }

  /// The channel drops a line over 64 KB, so an overlong message would lose the state too:
  /// Waiting for input, from a permission prompt quoting a very long command.
  @Test func averyLongMessageIsTrimmedSoItsReportStillFits() throws {
    let report = SessionStateReport(
      state: .attention, cwd: String(repeating: "d", count: 900),
      message: String(repeating: "x", count: 200_000))

    let message = try #require(report.message)
    #expect(
      message.count == SessionStateReport.maximumMessageLength + 1, "trimmed, with an ellipsis")
    #expect(message.hasSuffix("…"))
    #expect(try report.encodedLine().utf8.count < 64 * 1024, "the channel takes no more")

    let short = SessionStateReport(state: .attention, message: "Allow rm -rf?")
    #expect(short.message == "Allow rm -rf?", "anything a banner shows is left alone")
  }

  /// The app trusts only parsed reports, since any process of the user's can write to the
  /// channel, and a message under the line limit would otherwise reach a banner whole.
  @Test func aLongMessageIsTrimmedComingOffTheChannelAndNotOnlyGoingOntoIt() throws {
    let long = String(repeating: "x", count: 60_000)
    let report = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"attention","message":"\#(long)"}"#))

    let message = try #require(report.message)
    #expect(
      message.count == SessionStateReport.maximumMessageLength + 1, "trimmed, with an ellipsis")
    #expect(message.hasSuffix("…"))
  }

  @Test func aConversationIdLongerThanAnyAgentsIsDroppedComingOffTheChannel() throws {
    let long = String(repeating: "c", count: SessionStateReport.maximumIdentifierLength + 1)
    let dropped = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"running","conversation":"\#(long)"}"#))
    #expect(dropped.conversationID == nil)
    let kept = try #require(
      SessionStateReport.parse(
        #"{"v":1,"state":"running","conversation":"37880ecf-c5f3-42ce-afe0-82b221d75839"}"#))
    #expect(kept.conversationID == "37880ecf-c5f3-42ce-afe0-82b221d75839")
    #expect(SessionStateReport(state: .running, conversationID: "").conversationID == nil)
  }

  /// The same rule for the duration: the board renders it, and a value no
  /// clock could have produced is a writer's, not a command's.
  @Test func aDurationNoCommandCouldHaveTakenIsDroppedComingOffTheChannel() throws {
    for written in ["1e300", "-4", "1e9"] {
      let report = try #require(
        SessionStateReport.parse(#"{"v":1,"state":"done","duration":\#(written)}"#))
      #expect(report.duration == nil, "\(written)")
    }
    let real = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"done","duration":41.5}"#))
    #expect(real.duration == 41.5, "what a command actually took is kept")
  }

  /// The mark a pane draws comes off this word, and any process of the
  /// user's can write the line it arrives on.
  @Test func aCommandIsCutToItsFirstWordWithoutItsPathOrDroppedEntirely() throws {
    let kept = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"running","command":"/opt/bin/codex --resume"}"#))
    #expect(kept.command == "codex")
    let trailing = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"running","command":"/opt/bin/"}"#))
    #expect(
      trailing.command == "bin", "a trailing slash names the directory, as every path API has it")
    for written in ["/", "//", "   ", ""] {
      let report = try #require(
        SessionStateReport.parse(#"{"v":1,"state":"running","command":"\#(written)"}"#))
      #expect(report.command == nil, "[\(written)] names no program")
    }
  }

  /// Only the shell's own reports take an agent's mark back, so the field
  /// that says a shell sent one has to survive the wire both ways.
  @Test func aShellSaysSoOnItsOwnReportsAndNobodyElseDoes() throws {
    let sent = try #require(
      SessionStateReport.parse(SessionStateReport(state: .done, isShell: true).encodedLine()))
    #expect(sent.isShell == true)
    let scripted = try #require(SessionStateReport.parse(#"{"v":1,"state":"done"}"#))
    #expect(scripted.isShell == nil, "a line that does not claim it is not a shell's")
  }
}
