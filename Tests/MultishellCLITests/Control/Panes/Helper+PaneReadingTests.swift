import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperPaneReadingTests {
  @Test func aReadPrintsTheLastLinesItAsksForAsJSONWithoutTheBlankOnesBelow() async throws {
    let app = try ControlListener(reply: .output("one\ntwo\nthree\n\n   \n"))
    defer { app.stop() }
    let id = UUID()

    let screen = try await HelperBinary.run(
      ["panes", "read", id.uuidString, "--lines", "2"],
      environment: app.environment,
    )
    let all = try await HelperBinary.run(
      ["panes", "read", id.uuidString, "--scrollback", "--plain"],
      environment: app.environment,
    )

    let read = try JSONSerialization.jsonObject(with: Data(screen.standardOutput.utf8))
    #expect(
      (read as? [String: String]) == ["pane": id.uuidString, "text": "two\nthree"],
      "\(screen.standardOutput)\(screen.standardError)",
    )
    #expect(all.standardOutput == "one\ntwo\nthree\n")
    #expect(
      app.requests.received == [
        .readPane(id: id, includingScrollback: false),
        .readPane(id: id, includingScrollback: true),
      ]
    )
  }
}
