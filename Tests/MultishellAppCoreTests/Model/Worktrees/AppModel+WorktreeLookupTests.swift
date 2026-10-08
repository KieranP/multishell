import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelWorktreeLookupTests {
  /// A worktree added through a symlink chain has a long written path and a short real one,
  /// and a worktree nested inside its real path is deeper.
  @Test func depthIsMeasuredOnTheSpellingThatMatched() throws {
    let harness = Harness()
    let files = FileManager.default
    let real = harness.main.path.appendingPathComponent("real")
    let inner = real.appendingPathComponent("wt/inner")
    try files.createDirectory(at: inner, withIntermediateDirectories: true)
    let chain = harness.main.path.appendingPathComponent("a/b/c")
    try files.createDirectory(at: chain, withIntermediateDirectories: true)
    let link = chain.appendingPathComponent("d")
    try files.createSymbolicLink(at: link, withDestinationURL: real)
    let outer = Worktree(
      path: link.appendingPathComponent("wt"), projectID: harness.project.id, head: "c",
      branch: "outer")
    let nested = Worktree(path: inner, projectID: harness.project.id, head: "d", branch: "nested")
    harness.store.replaceWorktrees([harness.main, outer, nested], forProject: harness.project.id)

    let report = inner.appendingPathComponent("src").path
    #expect(
      harness.model.worktree(atPath: report)?.id == nested.id, "the real path is the deeper one")
    #expect(
      harness.model.worktree(atPath: real.appendingPathComponent("wt/lib").path)?.id == outer.id,
      "and the outer one is still found through its real path")
  }

  @Test func aReportFromAWorktreeWhoseDirectoryCameBackFindsItByItsRealPath()
    async throws
  {
    let harness = Harness()
    let (linked, real) = try worktreeListedThroughASymlink(harness)
    let report = real.appendingPathComponent("wt/src").path
    _ = harness.model.worktree(atPath: report)
    try await waitUntil { harness.model.pathResolutions.madeWhileMissing.contains(linked.id) }
    try FileManager.default.createDirectory(
      at: real.appendingPathComponent("wt"), withIntermediateDirectories: true)

    _ = harness.model.worktree(atPath: report)
    try await waitUntil { harness.model.pathResolutions.madeWhileMissing.isEmpty }

    #expect(harness.model.worktree(atPath: report)?.id == linked.id)
  }

  @Test func aWorktreeLookedUpWhileItsDirectoryWasMissingIsFoundByItsRealPathOnceItIsSeen()
    async throws
  {
    let harness = Harness()
    let (linked, real) = try worktreeListedThroughASymlink(harness)
    let report = real.appendingPathComponent("wt/src").path
    #expect(harness.model.worktree(atPath: report)?.id == harness.main.id)
    #expect(
      harness.model.pathResolutions.components[linked.id] != nil, "kept, not walked per report")
    try await waitUntil { harness.model.pathResolutions.madeWhileMissing.contains(linked.id) }

    try FileManager.default.createDirectory(
      at: real.appendingPathComponent("wt"), withIntermediateDirectories: true)
    harness.model.select(linked)

    #expect(harness.model.worktree(atPath: report)?.id == linked.id)
  }

  /// A worktree git lists under `link/wt`, where `link` leads to `real`, its
  /// directory not made yet.
  private func worktreeListedThroughASymlink(_ harness: Harness) throws -> (Worktree, real: URL) {
    let real = harness.main.path.appendingPathComponent("real")
    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    let link = harness.main.path.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let linked = Worktree(
      path: link.appendingPathComponent("wt"), projectID: harness.project.id, head: "c",
      branch: "linked")
    harness.store.replaceWorktrees([harness.main, linked], forProject: harness.project.id)
    return (linked, real)
  }
}
