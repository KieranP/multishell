import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperUICommandsTests {
  @Test func anUnknownWordAfterUIShowListsTheServicePagesWithTheViews() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["ui", "show", "pull-requests"],
      environment: app.environment,
    )

    #expect(output.status == 2)
    #expect(output.standardError.contains("board"), "\(output.standardError)")
    #expect(output.standardError.contains("ci, pull-request"), "\(output.standardError)")
  }
}
