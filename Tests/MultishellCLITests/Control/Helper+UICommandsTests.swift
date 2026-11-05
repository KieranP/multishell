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

  @Test func aViewWithTooManyWordsIsToldSoRatherThanThatItNeedsAView() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["ui", "show", "project-settings", "p-0123abcd", "extra"],
      environment: app.environment,
    )

    #expect(output.status == 2)
    #expect(!output.standardError.contains("needs a VIEW"), "\(output.standardError)")
    #expect(output.standardError.contains("one ID"), "\(output.standardError)")
    #expect(app.requests.received.isEmpty)
  }

  @Test func aSettingsPageIsAskedForWithItsScopeInOneRequest() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["ui", "show", "project-settings", "p-0123abcd", "--page", "hooks-delete"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(
      app.requests.received == [
        .showSettingsPage(.hooksDelete, inProject: true, project: "p-0123abcd")
      ]
    )
  }

  @Test func aPageNamedForAnotherViewOrUnknownIsRefusedBeforeAsking() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let board = try await HelperBinary.run(
      ["ui", "show", "board", "--page", "general"],
      environment: app.environment,
    )
    let unknown = try await HelperBinary.run(
      ["ui", "show", "settings", "--page", "fonts"],
      environment: app.environment,
    )

    #expect(board.status == 2)
    #expect(unknown.status == 2)
    #expect(unknown.standardError.contains("agent-hooks"), "\(unknown.standardError)")
    #expect(app.requests.received.isEmpty)
  }
}
