import Foundation
import MultishellGitKit
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct AppModelSharedSettingsExportTests {
  /// A key from a teammate's newer build is not the user's to drop, and
  /// nothing but `git diff` would show it gone.
  @Test func exportKeepsAKeyThisBuildDoesNotKnow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let file = try harness.writeSharedSettings(
      #"{ "$schema": "https://example.test/multishell.json", "branchPrefix": "team/" }"#
    )
    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.setSettings(ProjectSettings(iconTint: 3), for: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
    )
    #expect(json["$schema"] as? String == "https://example.test/multishell.json")
    #expect(json["branchPrefix"] as? String == "team/" && json["iconTint"] as? Int == 3)
    #expect(
      harness.project.sharedSettingsSnapshot.asWritten
        == (try SharedProjectSettings.load(from: harness.project.path))
    )
  }

  @Test func exportLeavesOutAGlyphNoBuildCanDraw() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(iconGlyph: "🚀", iconTint: 3), for: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.iconGlyph == nil, "an emoji left over from an older build is not the team's")
    #expect(written.iconTint == 3, "the tint it was set with still is")
  }

  @Test func exportWritesTheSettingsInForceAndTrustsItsOwnHooks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(
        branchPrefix: "team/",
        postCreateHook: "npm ci",
        linkedPaths: "node_modules",
        copiedPaths: ".env\n.env.*",
        iconGlyph: "server.rack",
        iconTint: 3,
      ),
      for: harness.project,
    )

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.branchPrefix == "team/" && written.postCreateHook == "npm ci")
    #expect(written.iconGlyph == "server.rack" && written.iconTint == 3)
    #expect(written.copiedPaths == ".env\n.env.*", "the file lists travel with the hooks")
    #expect(written.linkedPaths == "node_modules")
    #expect(
      written.trustCoveredText?.contains("copied:\n.env") == true,
      "and are asked about beside them",
    )
    #expect(written.trustCoveredText?.contains("linked:\nnode_modules") == true)
    #expect(written.worktreeDirectory == nil, "following the global is not exported")
    #expect(
      harness.project.sharedSettingsSnapshot.asWritten == written
    )
    #expect(harness.model.pendingSharedSettingsTrust == nil, "it is all the user's own words")
    #expect(
      harness.model.trustsSharedSettings(of: harness.project)
    )
    let text = try String(
      contentsOf: SharedProjectSettings.file(in: harness.project.path),
      encoding: .utf8,
    )
    #expect(text.hasPrefix("{\n  \"branchPrefix\""), "sorted and indented for a diff")
  }

  /// Export writes the settings in force, and a refused hook is not in force,
  /// so it is the file's word rather than the user's to drop.
  @Test func exportKeepsAHookTheUserRefusedToTrust() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "postCreateHook": "npm ci" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(false)
    harness.model.setSettings(
      harness.project.settings.with { $0.branchPrefix = "mine/" },
      for: harness.project,
    )

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.postCreateHook == "npm ci", "what they refused is still the file's")
    let project = harness.project
    #expect(
      !harness.model.trustsSharedSettings(of: project),
      "and exporting is not a way to trust it",
    )
    #expect(
      project.settings.trustDecision(about: written) == false,
      "the no travels to the new digest, so nothing asks again",
    )
  }

  /// The directory and the two path lists wait for the same yes the hooks do,
  /// so an export before that yes would have dropped them from the file.
  @Test func exportKeepsThePathsTheUserNeverTrusted() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(
      #"""
      { "worktreeDirectory": ".trees", "postCreateHook": "npm ci",
        "linkedPaths": "node_modules", "copiedPaths": ".env" }
      """#
    )
    await harness.model.refreshWorktrees(of: harness.project)
    harness.model.setSettings(ProjectSettings(branchPrefix: "mine/"), for: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.worktreeDirectory == ".trees")
    #expect(written.linkedPaths == "node_modules")
    #expect(written.copiedPaths == ".env")
    #expect(written.postCreateHook == "npm ci")
  }

  /// The yes was given about these words, and export writes them back
  /// unchanged, so the answer travels to the new bytes rather than lapsing.
  @Test func exportCarriesAYesOntoTheFileItRewrites() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(
      #"{ "worktreeDirectory": "../trees", "postCreateHook": "npm ci" }"#
    )
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(true)

    await harness.model.exportSharedSettings(for: harness.project)

    let project = harness.project
    #expect(
      harness.model.trustsSharedSettings(of: project),
      "the refused directory did not revoke it",
    )
    #expect(harness.model.effectiveSettings(for: project).postCreateHook == "npm ci")
  }

  /// Export records an answer it has, never one it does not: writing the
  /// file back is not the user saying no to a teammate's hook.
  @Test func exportDoesNotAnswerAQuestionTheUserWasNeverAsked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "postCreateHook": "npm ci" }"#)
    await harness.model.refreshWorktrees(of: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let project = harness.project
    let shared = try #require(project.sharedSettingsSnapshot.confined)
    #expect(project.settings.needsTrustDecision(for: shared), "so selecting still asks")
  }

  /// A hook the user wrote themselves still replaces the file's, and that
  /// file is theirs, so it is trusted as before.
  @Test func exportOverwritesAHookWithTheUsersOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try harness.writeSharedSettings(#"{ "postCreateHook": "npm ci" }"#)
    await harness.model.refreshWorktrees(of: harness.project)
    try harness.answerTrust(false)
    harness.model.setSettings(ProjectSettings(postCreateHook: "make setup"), for: harness.project)

    await harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.postCreateHook == "make setup")
    #expect(
      harness.model.trustsSharedSettings(of: harness.project)
    )
  }
}
