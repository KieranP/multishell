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
    #expect(SessionState.mostUrgent([.idle]) == nil)
    #expect(SessionState.mostUrgent([]) == nil)
    #expect(SessionState.idle.stored == nil)
    #expect(SessionState.done.stored == .done)
  }

  @Test func notificationPreferencesNeverNotifyForRunning() {
    for preference in NotificationPreference.allCases {
      #expect(!preference.notifies(.running), "\(preference)")
      #expect(!preference.notifies(.idle), "\(preference)")
    }
    #expect(NotificationPreference.attentionOnly.notifies(.attention))
    #expect(!NotificationPreference.attentionOnly.notifies(.done))
    #expect(NotificationPreference.attentionAndDone.notifies(.done))
    #expect(NotificationPreference.attentionAndDone.notifies(.error))
    #expect(!NotificationPreference.attentionOnly.notifies(.error))
    #expect(!NotificationPreference.off.notifies(.attention))
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
  }

  /// The channel drops a line over 64 KB as not speaking the protocol, so a
  /// message long enough to push a report past it would lose the state as
  /// well as the text — and the state it loses is Waiting for input, from a
  /// permission prompt quoting a very long command.
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

  /// The cap has to hold coming in, not only going out. The channel is a
  /// file any process of the user's can write to, so the reports the app
  /// trusts are the parsed ones, and a message well under the line limit
  /// would otherwise reach a notification body whole.
  @Test func aLongMessageIsTrimmedComingOffTheChannelAndNotOnlyGoingOntoIt() throws {
    let long = String(repeating: "x", count: 60_000)
    let report = try #require(
      SessionStateReport.parse(#"{"v":1,"state":"attention","message":"\#(long)"}"#))

    let message = try #require(report.message)
    #expect(
      message.count == SessionStateReport.maximumMessageLength + 1, "trimmed, with an ellipsis")
    #expect(message.hasSuffix("…"))
  }
}
