import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// A team ships the order its worktrees list in, the way it ships a worktree
/// path or a hook. Display only, so unlike a hook it needs no trust.
extension AppModelWorktreeOrderTests {
  @Test func theRepositorysOrderIsUsedUntilTheUserOverridesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Cut alphabetically last first, so the created order and the name
    // order disagree and only the file's answer can pass.
    for branch in ["zulu", "alpha"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
      try? await Task.sleep(for: .milliseconds(1100))
    }
    try #"{ "worktreeSortOrder": "createdOldestFirst" }"#
      .write(
        to: SharedProjectSettings.file(in: harness.project.path), atomically: true, encoding: .utf8)
    await harness.model.refresh(harness.project)

    let all = harness.model.workspace.worktrees
    #expect(harness.model.workspace.worktreeSortOrder == .alphabetical, "the user's global")
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "zulu", "alpha",
      ],
      "the file's order, which the global would have listed the other way")

    // A project overriding neither shows the file's value, said to come from the file, so
    // turning the override on seeds what the sidebar was already doing.
    let inherited = harness.model.inherited(
      .worktreeSortOrder, global: harness.model.workspace.worktreeSortOrder,
      for: harness.project)
    #expect(inherited == InheritedSetting(value: .createdOldestFirst, isFromRepository: true))
    #expect(inherited.caption.contains(SharedProjectSettings.fileName))

    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .alphabetical
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "alpha", "zulu",
      ],
      "the user's own order stands over the file's")
  }

  /// Export writes the order out, so a project set up by hand can be handed
  /// to the team without retyping it.
  @Test func exportCarriesTheOrderInForce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .committedNewestFirst
    settings.showsActiveWorktreesFirst = true
    harness.model.updateSettings(settings, for: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.worktreeSortOrder == .committedNewestFirst)
    #expect(written.showsActiveWorktreesFirst == true)
    #expect(harness.model.presentedError == nil)
  }
}
