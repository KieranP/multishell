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
    let h = Harness()
    let files = FileManager.default
    let real = h.main.path.appendingPathComponent("real")
    let inner = real.appendingPathComponent("wt/inner")
    try files.createDirectory(at: inner, withIntermediateDirectories: true)
    let chain = h.main.path.appendingPathComponent("a/b/c")
    try files.createDirectory(at: chain, withIntermediateDirectories: true)
    let link = chain.appendingPathComponent("d")
    try files.createSymbolicLink(at: link, withDestinationURL: real)
    let outer = Worktree(
      path: link.appendingPathComponent("wt"), projectID: h.project.id, head: "c", branch: "outer")
    let nested = Worktree(path: inner, projectID: h.project.id, head: "d", branch: "nested")
    h.store.replaceWorktrees([h.main, outer, nested], forProject: h.project.id)

    let report = inner.appendingPathComponent("src").path
    #expect(h.model.worktree(atPath: report)?.id == nested.id, "the real path is the deeper one")
    #expect(
      h.model.worktree(atPath: real.appendingPathComponent("wt/lib").path)?.id == outer.id,
      "and the outer one is still found through its real path")
  }

  @Test func aWorktreeNobodyPollsIsFoundByItsRealPathAReportAfterItsDirectoryReturns()
    async throws
  {
    let h = Harness()
    let files = FileManager.default
    let real = h.main.path.appendingPathComponent("real")
    try files.createDirectory(at: real, withIntermediateDirectories: true)
    let link = h.main.path.appendingPathComponent("link")
    try files.createSymbolicLink(at: link, withDestinationURL: real)
    let linked = Worktree(
      path: link.appendingPathComponent("wt"), projectID: h.project.id, head: "c",
      branch: "linked")
    h.store.replaceWorktrees([h.main, linked], forProject: h.project.id)
    let report = real.appendingPathComponent("wt/src").path
    _ = h.model.worktree(atPath: report)
    try await waitUntil { h.model.worktreesResolvedWhileMissing.contains(linked.id) }
    try files.createDirectory(
      at: real.appendingPathComponent("wt"), withIntermediateDirectories: true)

    _ = h.model.worktree(atPath: report)
    try await waitUntil { h.model.worktreesResolvedWhileMissing.isEmpty }

    #expect(h.model.worktree(atPath: report)?.id == linked.id)
  }

  @Test func aWorktreeLookedUpWhileItsDirectoryWasMissingIsFoundByItsRealPathOnceItIsSeen()
    async throws
  {
    let h = Harness()
    let files = FileManager.default
    let real = h.main.path.appendingPathComponent("real")
    try files.createDirectory(at: real, withIntermediateDirectories: true)
    let link = h.main.path.appendingPathComponent("link")
    try files.createSymbolicLink(at: link, withDestinationURL: real)
    let linked = Worktree(
      path: link.appendingPathComponent("wt"), projectID: h.project.id, head: "c",
      branch: "linked")
    h.store.replaceWorktrees([h.main, linked], forProject: h.project.id)
    let report = real.appendingPathComponent("wt/src").path
    #expect(h.model.worktree(atPath: report)?.id == h.main.id)
    #expect(h.model.resolvedWorktreeComponents[linked.id] != nil, "kept, not walked per report")
    try await waitUntil { h.model.worktreesResolvedWhileMissing.contains(linked.id) }

    try files.createDirectory(
      at: real.appendingPathComponent("wt"), withIntermediateDirectories: true)
    h.model.select(linked)

    #expect(h.model.worktree(atPath: report)?.id == linked.id)
  }
}
