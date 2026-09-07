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
      duration: 12.5, agent: "claude")
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
}
