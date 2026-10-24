import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeCreationTests {
  @Test func aCreateAtAPathWhoseRemovalStillRunsIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let (_, removal) = try await harness.removalHeld(
      in: .postDeleteHook,
      by: ProjectSettings(postDeleteHook: harness.holdLine(until: gate)),
    )
    await harness.model.refreshWorktrees(of: harness.project)

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
    #expect(harness.worktree(onBranch: "leaving") == nil)
  }

  @Test func aCreateThroughASymlinkToAPathWhoseRemovalStillRunsIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let real = harness.root.appendingPathComponent("trees-real", isDirectory: true)
    let link = harness.root.appendingPathComponent("trees-link")
    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let gate = harness.root.appendingPathComponent("gate")
    let (_, removal) = try await harness.removalHeld(
      in: .postDeleteHook,
      by: ProjectSettings(
        worktreeDirectory: link.path,
        postDeleteHook: harness.holdLine(until: gate),
      ),
    )
    await harness.model.refreshWorktrees(of: harness.project)

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
  }

  @Test func aCreateAtAPathWhoseRemovalIsInItsPreDeleteHookIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("gate")
    let (_, removal) = try await harness.removalHeld(
      in: .preDeleteHook,
      by: ProjectSettings(preDeleteHook: harness.holdLine(until: gate)),
    )

    let again = await harness.model.createWorktree(
      branch: "leaving",
      basedOn: nil,
      createsBranch: false,
      in: harness.project,
    )
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(again == nil)
    #expect(harness.model.presentedError?.title == "A removal is still running there")
  }
}
