import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsTests {
  private let defaults = WorktreeSettings.globalDefaults

  @Test func everyStoredFieldIsWrittenUnderItsOwnKey() throws {
    var everyField = ProjectSettings(
      worktreeDirectory: "trees", branchPrefix: "k/", defaultBranch: "main",
      preCreateHook: "a", postCreateHook: "b", preDeleteHook: "c", postDeleteHook: "d",
      linkedPaths: "node_modules", copiedPaths: ".env", preferredAgentID: "codex",
      agentFlags: "--yolo", autoStartsAgent: true, autoStartsAgentOnCreate: true,
      opensTerminalOnSelect: true, opensTerminalOnCreate: true, worktreeSortOrder: .alphabetical,
      showsActiveWorktreesFirst: true, preferredShellID: "/bin/zsh", iconGlyph: "star", iconTint: 2)
    everyField.trustDecisions = [TrustDecision(digest: "beef", isTrusted: true)]
    let fields = Mirror(reflecting: everyField).children.count
    let encoded = try JSONEncoder().encode(everyField)
    let keys = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys

    #expect(keys.count == fields, "a field missing from CodingKeys is silently never saved")
  }

  /// Kept, not coerced: these fields have no other spelling for "none". A
  /// project pinned to no prefix used to follow the global again on the next load.
  @Test func aBlankWorktreeFieldDecodesAsTheOverrideToNone() throws {
    let settings = try decodeJSON(
      ProjectSettings.self,
      #"{ "worktreeDirectory": "", "branchPrefix": "", "defaultBranch": "", "postCreateHook": "" }"#
    )

    #expect(settings.branchPrefix == "")
    #expect(settings.worktreeDirectory == "")
    #expect(settings.defaultBranch == "")
    #expect(
      settings.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "",
      "not the global's team/")
    #expect(
      try decodeJSON(ProjectSettings.self, #"{ "defaultBranch": "develop" }"#).defaultBranch
        == "develop")
  }

  /// Read back by someone whose own global has a prefix, the file has to
  /// still say none, or the team gets the opposite of what was shared.
  @Test func aBlankOverrideSurvivesAnExportAndTheFileItIsWrittenTo() throws {
    let exported = SharedProjectSettings(exporting: ProjectSettings(branchPrefix: ""))
    #expect(exported.branchPrefix == "")

    let read = try writtenAndReadBack(exported)
    #expect(read.branchPrefix == "")
    // The reader leaves it alone, so the file's answer stands over a global
    // that has a prefix of its own.
    let inEffect = ProjectSettings().layered(over: read).effectiveWorktreeSettings(
      defaults: defaults)
    #expect(inEffect.branchPrefix == "")
    #expect(inEffect.qualifiedBranch("tabs") == "tabs")
  }

  /// A field with its own spelling for "none", `login` for the shell, reads
  /// `""` as noise and keeps following the global.
  @Test func aBlankFieldWithASentinelOfItsOwnStaysNoOverride() throws {
    let settings = try decodeJSON(
      ProjectSettings.self,
      #"{ "preferredAgentID": "", "defaultShell": "", "iconGlyph": "" }"#)

    #expect(settings.preferredAgentID == nil)
    #expect(settings.preferredShellID == nil)
    #expect(settings.iconGlyph == nil)
  }

  /// What the bug actually cost: the trip through the store and the
  /// workspace's encoding, which is where the override used to be lost.
  @Test @MainActor func aBlankOverrideSurvivesTheStoreAndTheWorkspacesEncoding() throws {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    store.setSettings(ProjectSettings(branchPrefix: ""), forProject: project.id)

    let data = try JSONEncoder().encode(store.workspace)
    let restored = try JSONDecoder().decode(Workspace.self, from: data)
    let settings = try #require(restored.project(project.id)?.settings)

    #expect(settings.branchPrefix == "", "the project is still pinned to no prefix")
    #expect(settings.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "")
  }
}
