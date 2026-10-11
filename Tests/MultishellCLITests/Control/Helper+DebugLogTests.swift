import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperDebugLogTests {
  @Test func theLogIsTheRunningAppsOwnLinesAsJSONOneALineUnlessPlain() {
    let predicate = #"subsystem == "io.multishell.app" AND processID == 42"#
    let app = (pid: Int32(42), subsystem: "io.multishell.app")

    #expect(
      Helper.logArguments(pid: app.pid, subsystem: app.subsystem, span: "5m", follows: false)
        == [
          "show", "--last", "5m", "--info", "--debug", "--style", "ndjson", "--predicate",
          predicate,
        ]
    )
    #expect(
      Helper.logArguments(
        pid: app.pid,
        subsystem: app.subsystem,
        span: "5m",
        follows: true,
        isPlain: true,
      ) == ["stream", "--level", "debug", "--style", "compact", "--predicate", predicate]
    )
  }

  @Test func theLogFromAHelperInNoBundleSaysSo() async throws {
    let unbundled = try await HelperBinary.run(["debug", "log"])
    #expect(unbundled.status == 1)
    #expect(unbundled.standardError.contains("no app bundle"), "\(unbundled.standardError)")
  }

  @Test func aSpanTheLogToolCannotReadIsAUsageError() async throws {
    #expect(try await HelperBinary.run(["debug", "log", "--since", "soon"]).status == 2)
  }

  @Test func aLogSpanWhileFollowingIsAUsageError() async throws {
    #expect(try await HelperBinary.run(["debug", "log", "--follow", "--since", "5m"]).status == 2)
  }

  @Test func onlyTheLogsJSONLinesArePrintedNotTheToolsOwnHeader() throws {
    let tool = Pipe()
    tool.fileHandleForWriting.write(
      Data(#"Filtering the log data using "x"\#n{"a":1}\#n{"b":2}\#n"#.utf8)
    )
    try tool.fileHandleForWriting.close()
    var lines: [String] = []

    try Helper.forEachJSONLine(in: tool.fileHandleForReading) { lines.append($0) }

    #expect(lines == [#"{"a":1}"#, #"{"b":2}"#])
  }

  @Test func aLastLineTheToolEndedWithoutANewlineIsStillPrinted() throws {
    let tool = Pipe()
    tool.fileHandleForWriting.write(Data(#"{"a":1}\#n{"b":2}"#.utf8))
    try tool.fileHandleForWriting.close()
    var lines: [String] = []

    try Helper.forEachJSONLine(in: tool.fileHandleForReading) { lines.append($0) }

    #expect(lines == [#"{"a":1}"#, #"{"b":2}"#])
  }
}
