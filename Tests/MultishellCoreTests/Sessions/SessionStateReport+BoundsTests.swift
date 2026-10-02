import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SessionStateReportBoundsTests {
  @Test func everyStringOffTheChannelIsBounded() {
    let long = String(repeating: "x", count: 12_000)
    let shells = (1...500).map(String.init).joined(separator: ",")
    let line = """
      {"state":"running","agent":"\(long)","cwd":"/\(long)","command":"\(long) arg",\
      "subagent":{"id":"\(long)","type":"\(long)","phase":"started"},\
      "shells":[\(shells)]}
      """
    let report = SessionStateReport.parse(line)

    #expect(report?.agentID == nil)
    #expect(report?.workingDirectory == nil)
    #expect(report?.command == nil)
    #expect(report?.worker?.id == WorkerReport.anonymousID)
    #expect(report?.worker?.type?.count == WorkerReport.maximumTypeLength + 1)
    #expect(report?.backgroundShells?.count == SessionStateReport.rosterCapacity)
  }

  @Test func aStopNamesAsManyWorkersOutAsARosterHoldsAndOnlyNamedOnes() {
    let count = SessionStateReport.maximumWorkersOut + 10
    let out = (1...count).map { #"{"id":"w\#($0)","phase":"working"}"# }.joined(separator: ",")
    let long = String(repeating: "x", count: 200)
    let report = SessionStateReport.parse(
      #"{"state":"done","out":[{"id":"\#(long)","phase":"working"},\#(out)]}"#)
    #expect(
      report?.workersOut?.count == SessionStateReport.maximumWorkersOut,
      "as many as a roster's places and folds")
    #expect(report?.workersOut?.first?.id == "w1", "the unnamed one is dropped")
  }

  @Test func fieldsWithinTheirBoundsArriveAndACommandArrivesAsItsExecutable() {
    let report = SessionStateReport.parse(
      #"{"state":"running","agent":"codex","cwd":"/w/repo","command":"/bin/make all","#
        + #""subagent":{"id":"t1","type":"Explore","phase":"working"}}"#)

    #expect(report?.agentID == "codex")
    #expect(report?.workingDirectory == "/w/repo")
    #expect(report?.command == "make")
    #expect(report?.worker == WorkerReport(id: "t1", type: "Explore", phase: .working))
  }

  /// The channel drops a line over 64 KB, so an overlong message would lose the state too:
  /// Waiting for input, from a permission prompt quoting a very long command.
  @Test func aVeryLongMessageIsTrimmedSoItsReportStillFits() throws {
    let report = SessionStateReport(
      state: .attention, workingDirectory: String(repeating: "d", count: 900),
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
}
