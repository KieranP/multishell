import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelSharedSettingsTests {
  /// A key from a teammate's newer build is not the user's to drop, and
  /// nothing but `git diff` would show it gone.
  @Test func exportKeepsAKeyThisBuildDoesNotKnow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "$schema": "https://example.test/multishell.json", "branchPrefix": "team/" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.updateSettings(ProjectSettings(iconTint: 3), for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(json["$schema"] as? String == "https://example.test/multishell.json")
    #expect(json["branchPrefix"] as? String == "team/" && json["iconTint"] as? Int == 3)
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten
        == (try SharedProjectSettings.load(from: h.project.path))
    )
  }

  @Test func exportLeavesOutAGlyphNoBuildCanDraw() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(iconGlyph: "🚀", iconTint: 3), for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.iconGlyph == nil, "an emoji left over from an older build is not the team's")
    #expect(written.iconTint == 3, "the tint it was set with still is")
  }

  @Test func exportWritesTheSettingsInForceAndTrustsItsOwnHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(
        branchPrefix: "team/", postCreateHook: "npm ci", linkedPaths: "node_modules",
        copiedPaths: ".env\n.env.*",
        iconGlyph: "server.rack", iconTint: 3),
      for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "team/" && written.postCreateHook == "npm ci")
    #expect(written.iconGlyph == "server.rack" && written.iconTint == 3)
    #expect(written.copiedPaths == ".env\n.env.*", "the file lists travel with the hooks")
    #expect(written.linkedPaths == "node_modules")
    #expect(
      written.trustCoveredText?.contains("copied:\n.env") == true,
      "and are asked about beside them")
    #expect(written.trustCoveredText?.contains("linked:\nnode_modules") == true)
    #expect(written.worktreeDirectory == nil, "following the global is not exported")
    #expect(h.model.workspace.project(h.project.id)?.sharedSettings.asWritten == written)
    #expect(h.model.pendingSharedSettingsTrust == nil, "it is all the user's own words")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    let text = try String(
      contentsOf: SharedProjectSettings.file(in: h.project.path), encoding: .utf8)
    #expect(text.hasPrefix("{\n  \"branchPrefix\""), "sorted and indented for a diff")
  }

  /// Export writes the settings in force, and a refused hook is not in force,
  /// so it is the file's word rather than the user's to drop.
  @Test func exportKeepsAHookTheUserRefusedToTrust() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: false)
    h.model.updateSettings(
      h.project.settings.with { $0.branchPrefix = "mine/" }, for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.postCreateHook == "npm ci", "what they refused is still the file's")
    let project = try #require(h.model.workspace.project(h.project.id))
    #expect(!h.model.trustsSharedSettings(of: project), "and exporting is not a way to trust it")
    #expect(
      project.settings.trustDecision(about: written) == false,
      "the no travels to the new digest, so nothing asks again")
  }

  /// The directory and the two path lists wait for the same yes the hooks do,
  /// so an export before that yes would have dropped them from the file.
  @Test func exportKeepsThePathsTheUserNeverTrusted() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"""
    { "worktreeDirectory": ".trees", "postCreateHook": "npm ci",
      "linkedPaths": "node_modules", "copiedPaths": ".env" }
    """#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.updateSettings(ProjectSettings(branchPrefix: "mine/"), for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.worktreeDirectory == ".trees")
    #expect(written.linkedPaths == "node_modules")
    #expect(written.copiedPaths == ".env")
    #expect(written.postCreateHook == "npm ci")
  }

  /// The yes was given about these words, and export writes them back
  /// unchanged, so the answer travels to the new bytes rather than lapsing.
  @Test func exportCarriesAYesOntoTheFileItRewrites() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "../trees", "postCreateHook": "npm ci" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    await h.model.exportSharedSettings(for: h.project)

    let project = try #require(h.model.workspace.project(h.project.id))
    #expect(h.model.trustsSharedSettings(of: project), "the refused directory did not revoke it")
    #expect(h.model.effectiveSettings(for: project).postCreateHook == "npm ci")
  }

  /// Export records an answer it has, never one it does not: writing the
  /// file back is not the user saying no to a teammate's hook.
  @Test func exportDoesNotAnswerAQuestionTheUserWasNeverAsked() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    await h.model.exportSharedSettings(for: h.project)

    let project = try #require(h.model.workspace.project(h.project.id))
    let shared = try #require(project.sharedSettings.confined)
    #expect(project.settings.needsTrustDecision(for: shared), "so selecting still asks")
  }

  /// A hook the user wrote themselves still replaces the file's, and that
  /// file is theirs, so it is trusted as before.
  @Test func exportOverwritesAHookWithTheUsersOwn() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: false)
    h.model.updateSettings(ProjectSettings(postCreateHook: "make setup"), for: h.project)

    await h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.postCreateHook == "make setup")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
  }
}
