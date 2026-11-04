import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperWorktreeCommandsTests {
  @Test func aWorktreeCommandNamesItsBranchProjectAndFirstTab() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      [
        "worktrees", "add", "p-0123abcd", "feat/x", "--from", "main", "--agent", "codex",
        "--prompt", "fix the build",
      ],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    let expected = NewWorktreeOrder(
      branch: "feat/x",
      projectID: "p-0123abcd",
      createsBranch: true,
      startPoint: "main",
      agentID: "codex",
      task: "fix the build",
    )
    #expect(app.requests.received == [.newWorktree(expected)])
  }
}
