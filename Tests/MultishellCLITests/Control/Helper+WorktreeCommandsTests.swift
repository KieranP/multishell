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
      project: .id("p-0123abcd"),
      createsBranch: true,
      startPoint: "main",
      agentID: "codex",
      task: "fix the build",
    )
    #expect(app.requests.received == [.newWorktree(expected)])
  }

  @Test func aWorktreeCommandWithNoProjectNamesTheFolderItRunsIn() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["worktrees", "add", "feat/x", "--prompt", "fix the build"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    // The helper runs in /tmp, which getcwd answers as its target.
    let here = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path
    let expected = NewWorktreeOrder(
      branch: "feat/x",
      project: .holding(directory: here),
      createsBranch: true,
      startPoint: nil,
      agentID: nil,
      task: "fix the build",
    )
    #expect(app.requests.received == [.newWorktree(expected)])
  }

  @Test func aWorktreeCommandGivenAProjectIDAndNoBranchIsAUsageError() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["worktrees", "add", "p-0123abcd"],
      environment: app.environment,
    )

    #expect(output.status == 2, "\(output.standardError)")
    #expect(app.requests.received.isEmpty)
  }
}
