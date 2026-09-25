import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsTests {
  private let defaults = WorktreeSettings(worktreeDirectory: "/global/trees", branchPrefix: "team/")

  @Test func everyStoredFieldIsWrittenUnderItsOwnKey() throws {
    let everyField = ProjectSettings(
      worktreeDirectory: "trees", branchPrefix: "k/", defaultBranch: "main",
      preCreateHook: "a", postCreateHook: "b", preDeleteHook: "c", postDeleteHook: "d",
      linkedPaths: "node_modules", copiedPaths: ".env", preferredAgentID: "codex",
      agentFlags: "--yolo", autoStartAgent: true, autoStartAgentOnCreate: true,
      opensTerminalOnSelect: true, opensTerminalOnCreate: true, worktreeSortOrder: .alphabetical,
      showsActiveWorktreesFirst: true, preferredShellID: "/bin/zsh", iconGlyph: "star", iconTint: 2,
      trustDecisions: [TrustDecision(digest: "beef", trusted: true)])
    let fields = Mirror(reflecting: everyField).children.count
    let encoded = try JSONEncoder().encode(everyField)
    let keys = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys

    #expect(keys.count == fields, "a field missing from CodingKeys is silently never saved")
  }

  @Test func nilFieldsFallBackToTheGlobalDefaults() {
    let effective = ProjectSettings().effectiveWorktreeSettings(defaults: defaults)
    #expect(effective == defaults)
  }

  @Test func eachFieldOverridesIndependently() {
    let effective = ProjectSettings(branchPrefix: "kieran/").effectiveWorktreeSettings(
      defaults: defaults)
    #expect(effective.worktreeDirectory == "/global/trees")
    #expect(effective.branchPrefix == "kieran/")
  }

  @Test func aWhitespaceOverrideMeansNone() {
    // The sheet stores a lone space to opt a project out of a global
    // prefix; it must not end up in the branch name.
    let effective = ProjectSettings(branchPrefix: " ").effectiveWorktreeSettings(defaults: defaults)
    #expect(effective.branchPrefix == "")
    #expect(effective.qualifiedBranch("tabs") == "tabs")
  }

  /// These fields have no other spelling for "none". A project pinned to no
  /// prefix used to follow the global again on the next load.
  @Test func aBlankWorktreeFieldDecodesAsTheOverrideToNone() throws {
    let json = Data(
      #"{ "worktreeDirectory": "", "branchPrefix": "", "defaultBranch": "", "postCreateHook": "" }"#
        .utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)

    #expect(settings.branchPrefix == "")
    #expect(settings.worktreeDirectory == "")
    #expect(settings.defaultBranch == "")
    #expect(
      settings.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "",
      "not the global's team/")
  }

  /// Read back by someone whose own global has a prefix, the file has to
  /// still say none, or the team gets the opposite of what was shared.
  @Test func aBlankOverrideSurvivesAnExportAndTheFileItIsWrittenTo() throws {
    let repository = try Scratch.directory("export")
    defer { try? FileManager.default.removeItem(at: repository) }

    let exported = SharedProjectSettings(exporting: ProjectSettings(branchPrefix: ""))
    #expect(exported.branchPrefix == "")
    try exported.write(to: repository)

    let read = try #require(try SharedProjectSettings.load(from: repository))
    #expect(read.branchPrefix == "")
    // The reader leaves it alone, so the file's answer stands over a global
    // that has a prefix of its own.
    let inEffect = ProjectSettings().layered(over: read).effectiveWorktreeSettings(
      defaults: defaults)
    #expect(inEffect.branchPrefix == "")
    #expect(inEffect.qualifiedBranch("tabs") == "tabs")
  }

  /// A field with its own spelling for "none" reads `""` as noise and keeps
  /// following the global.
  @Test func aBlankFieldWithASentinelOfItsOwnStaysNoOverride() throws {
    let json = Data(#"{ "preferredAgentID": "", "defaultShell": "", "iconGlyph": "" }"#.utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)

    #expect(settings.preferredAgentID == nil)
    #expect(settings.preferredShellID == nil)
    #expect(settings.iconGlyph == nil)
  }

  /// What the bug actually cost: the whole trip through the store and the
  /// file, which is where the override used to be lost.
  @Test @MainActor func aBlankOverrideSurvivesASaveAndLoad() throws {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    store.updateSettings(ProjectSettings(branchPrefix: ""), forProject: project.id)

    let data = try JSONEncoder().encode(store.workspace)
    let restored = try JSONDecoder().decode(Workspace.self, from: data)
    let settings = try #require(restored.project(project.id)?.settings)

    #expect(settings.branchPrefix == "", "the project is still pinned to no prefix")
    #expect(settings.effectiveWorktreeSettings(defaults: defaults).branchPrefix == "")
  }
}
