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
      state: .attention, sessionID: id, workingDirectory: "/w/repo", pid: 4242,
      message: "Needs permission",
      duration: 12.5, agentID: "claude", isSilent: true, asksQuestion: true)
    let line = try report.encodedLine()
    #expect(line.hasSuffix("\n"))
    #expect(!line.dropLast().contains("\n"), "one line per message")
    #expect(SessionStateReport.parse(line) == report)
  }

  @Test func onlyTheStateIsRequiredAndTheVersionDefaultsToOne() {
    let report = SessionStateReport.parse(#"{"state":"running"}"#)
    #expect(report?.state == .running)
    #expect(report?.version == 1)
    #expect(report?.sessionID == nil && report?.workingDirectory == nil && report?.pid == nil)
    #expect(report?.duration == nil)
    #expect(report?.agentID == nil, "an older helper names no agent and still reports")
    #expect(report?.isSilent == nil, "absent is the usual: the report raises its banner")
  }

  /// The dot moves on the first of the two reports a permission prompt
  /// makes, and the banner waits for the second.
  @Test func aSilentReportIsCarriedAndKeepsItsBannerBack() throws {
    let silent = SessionStateReport(state: .attention, isSilent: true)
    #expect(try silent.encodedLine().contains("\"silent\":true"))
    #expect(SessionStateReport.parse(try silent.encodedLine())?.isSilent == true)
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

  /// Only the shell's own reports take an agent's mark back, so the field
  /// that says a shell sent one has to survive the wire both ways.
  @Test func aShellSaysSoOnItsOwnReportsAndNobodyElseDoes() throws {
    let sent = try #require(
      SessionStateReport.parse(
        SessionStateReport(state: .done, isFromShellIntegration: true).encodedLine()))
    #expect(sent.isFromShellIntegration == true)
    let scripted = try #require(SessionStateReport.parse(#"{"v":1,"state":"done"}"#))
    #expect(
      scripted.isFromShellIntegration == nil, "a line that does not claim it is not a shell's")
  }

  /// The field a worker rides on, both directions: an older helper and an older
  /// app each have to meet a newer one over the shared helper link.
  @Test func aSubagentSurvivesTheWireBothWays() throws {
    let worker = WorkerReport(id: "agent_1", type: "Explore", phase: .working)
    let sent = SessionStateReport(state: .running, agentID: "claude", worker: worker)
    let line = try sent.encodedLine()
    #expect(line.contains(#""subagent":{"id":"agent_1","phase":"working","type":"Explore"}"#))
    #expect(try #require(SessionStateReport.parse(line)) == sent)
    #expect(SessionStateReport.parse(line)?.workerChange == worker)

    let quiet = try SessionStateReport(state: .done).encodedLine()
    #expect(!quiet.contains("subagent"), "a report that is not about them says nothing")
    #expect(SessionStateReport.parse(quiet)?.workerChange == nil)

    let old = #"{"v":1,"state":"done","agent":"claude"}"#
    #expect(SessionStateReport.parse(old)?.workerChange == nil, "absent reads as no change")
    // What an older helper writes: a count, read as an unnamed worker.
    let counted = #"{"v":1,"state":"running","subagents":1,"somethingLater":true}"#
    #expect(
      SessionStateReport.parse(counted)?.workerChange
        == WorkerReport(id: WorkerReport.anonymousID, phase: .started))
    let uncounted = #"{"v":1,"state":"running","subagents":-1}"#
    #expect(
      SessionStateReport.parse(uncounted)?.workerChange
        == WorkerReport(id: WorkerReport.anonymousID, phase: .ended))
  }

  /// The other direction: a newer helper writing to an older app, which reads
  /// the count and ignores the object. A tool call carries no count.
  @Test func aNewHelpersWorkerIsCountedForAnOlderApp() throws {
    func line(_ phase: WorkerReport.Phase) throws -> String {
      try SessionStateReport(
        state: .running, worker: WorkerReport(id: "agent_1", type: "Explore", phase: phase)
      ).encodedLine()
    }
    #expect(try line(.started).contains(#""subagents":1"#))
    #expect(try line(.ended).contains(#""subagents":-1"#))
    #expect(try !line(.working).contains(#""subagents""#))

    let start = try line(.started)
    #expect(
      SessionStateReport.parse(start)?.workerChange
        == WorkerReport(id: "agent_1", type: "Explore", phase: .started),
      "a new app still reads the named worker, not the count")
  }
}
