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
      state: .attention,
      sessionID: id,
      workingDirectory: "/w/repo",
      pid: 4242,
      message: "Needs permission",
      duration: 12.5,
      agentID: "claude",
      isSilent: true,
      asksQuestion: true,
    )
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
      #"{"v":7,"state":"done","session":"\#(UUID().uuidString)","colour":"amber"}"#
    )
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
        SessionStateReport(state: .done, isFromShellIntegration: true).encodedLine()
      )
    )
    #expect(sent.isFromShellIntegration == true)
    let scripted = try #require(SessionStateReport.parse(#"{"v":1,"state":"done"}"#))
    #expect(
      scripted.isFromShellIntegration == nil,
      "a line that does not claim it is not a shell's",
    )
  }
}
