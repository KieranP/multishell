import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeRemovalTests {
  @Test func theRefreshARemovalCausesKeepsItsRowHookAndBlockToItsEnd() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let written = harness.root.appendingPathComponent("post-delete.txt")
    let (leaving, removal) = try await harness.removalHeld(
      in: .postDeleteHook,
      by: ProjectSettings(
        postDeleteHook: harness.holdLine(until: gate)
          + "; printf %s \"$MULTISHELL_PORT\" > '\(written.path)'"
      ),
    )

    await harness.model.refreshWorktrees(of: harness.project)
    #expect(harness.model.workspace.worktree(leaving.id) != nil, "its row, with Cancel, stays")
    let arriving = try await harness.createWorktree(onBranch: "arriving")
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(try String(contentsOf: written, encoding: .utf8) == "3010", "ran to its end")
    #expect(harness.model.workspace.port(of: arriving.id) == 3020, "3010 was still held")
    #expect(harness.model.workspace.worktree(leaving.id) == nil)
    #expect(harness.model.workspace.portBlocks[leaving.id] == nil, "freed once it ended")
  }

  @Test func aWorktreeRemovedOutsideTheAppDuringItsPreDeleteHookEndsThatRemoval() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let (leaving, removal) = try await harness.removalHeld(
      in: .preDeleteHook,
      by: ProjectSettings(preDeleteHook: harness.holdLine(until: gate)),
    )

    try await harness.removeOutsideTheApp(leaving.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.worktreeOperations[leaving.id] == nil)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value
  }
}
