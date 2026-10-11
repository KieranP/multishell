import Testing

@testable import MultishellCLI

@Suite
struct CommandOptionsTests {
  private func options(_ name: String, _ value: String) throws -> CommandOptions {
    try CommandOptions([name, value], valued: ["lines", "timeout"], topic: "panes")
  }

  @Test func aCountOrSecondsGivenIsReadAndOneNotGivenIsNil() throws {
    #expect(try options("--lines", "3").count("lines") == 3)
    #expect(try options("--timeout", "1.5").seconds("timeout") == .milliseconds(1500))
    #expect(try options("--lines", "3").seconds("timeout") == nil)
  }

  @Test func aCountOrSecondsOutOfRangeOrNoNumberIsAUsageError() throws {
    for value in ["0", "-1", "x"] {
      #expect(throws: UsageError.self, "\(value)") { try options("--lines", value).count("lines") }
    }
    for value in ["0", "86401", "nan", "x"] {
      #expect(throws: UsageError.self, "\(value)") {
        try options("--timeout", value).seconds("timeout")
      }
    }
  }
}
