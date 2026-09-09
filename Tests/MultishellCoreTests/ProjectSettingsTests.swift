import Foundation
import Testing

@testable import MultishellCore

@Suite
struct WorktreeSettingsTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  @Test func theDefaultContainerIsASiblingNamedAfterTheProject() {
    #expect(
      WorktreeSettings().worktreeContainer(for: project).path
        == "/Users/dev/Work/multishell-worktrees")
  }

  @Test func anAbsoluteContainerIgnoresTheRepositoryPath() {
    let settings = WorktreeSettings(worktreeDirectory: "/tmp/trees")
    #expect(settings.worktreeContainer(for: project).path == "/tmp/trees")
  }

  @Test func aRelativeContainerResolvesAgainstTheRepository() {
    let settings = WorktreeSettings(worktreeDirectory: ".worktrees")
    #expect(
      settings.worktreeContainer(for: project).path == "/Users/dev/Work/multishell/.worktrees")
  }

  @Test func resolutionDoesNotDependOnTheDirectoryExisting() {
    // The fixture path does not exist on any machine; the answer must not
    // change between a machine where it does and one where it does not.
    let ghost = Project(path: URL(fileURLWithPath: "/nowhere/at/all/repo"))
    let settings = WorktreeSettings(worktreeDirectory: ".worktrees")
    #expect(settings.worktreeContainer(for: ghost).path == "/nowhere/at/all/repo/.worktrees")
    #expect(
      WorktreeSettings().worktreeContainer(for: ghost).path == "/nowhere/at/all/repo-worktrees")
  }

  @Test func aBlankContainerMeansTheDefaultNotTheRepository() {
    // An override cleared to nothing, or the global field emptied, would
    // otherwise put worktrees inside the main checkout as untracked files.
    for text in ["", " ", "\t"] {
      let settings = WorktreeSettings(worktreeDirectory: text)
      #expect(
        settings.worktreeContainer(for: project).path == "/Users/dev/Work/multishell-worktrees",
        "\(text.debugDescription)")
    }
    let overridden = ProjectSettings(worktreeDirectory: " ").effective(
      defaults: WorktreeSettings(worktreeDirectory: "/global/trees"))
    #expect(
      overridden.worktreeContainer(for: project).path == "/Users/dev/Work/multishell-worktrees")
  }

  @Test func slashesInBranchNamesBecomeOneDirectory() {
    let path = WorktreeSettings().worktreePath(forBranch: "feat/tabs", in: project)
    #expect(path.path == "/Users/dev/Work/multishell-worktrees/feat-tabs")
  }

  @Test func noBranchNameCanPutAWorktreeOutsideTheContainer() {
    // git rejects most of these as branch names, but the path is computed
    // and shown, and its parent created, before git is asked.
    let container = WorktreeSettings().worktreeContainer(for: project).path
    for name in ["..", ".", "", " ", "../..", "/", "//", "a/../../b", "...", "./x", "-"] {
      let path = WorktreeSettings().worktreePath(forBranch: name, in: project).standardizedFileURL
        .path
      #expect(path.hasPrefix(container + "/"), "\(name) -> \(path)")
      #expect(path.count > container.count + 1, "\(name) must name something")
    }
  }

  @Test func theBranchPrefixIsAppliedOnce() {
    let settings = WorktreeSettings(branchPrefix: "kieran/")
    #expect(settings.qualifiedBranch("tabs") == "kieran/tabs")
    #expect(settings.qualifiedBranch("kieran/tabs") == "kieran/tabs")
  }

  @Test func anEmptyPrefixLeavesTheNameAlone() {
    #expect(WorktreeSettings().qualifiedBranch(" tabs ") == "tabs")
  }
}

@Suite
struct ProjectSettingsTests {
  private let defaults = WorktreeSettings(worktreeDirectory: "/global/trees", branchPrefix: "team/")

  @Test func nilFieldsFallBackToTheGlobalDefaults() {
    let effective = ProjectSettings().effective(defaults: defaults)
    #expect(effective == defaults)
  }

  @Test func eachFieldOverridesIndependently() {
    let effective = ProjectSettings(branchPrefix: "kieran/").effective(defaults: defaults)
    #expect(effective.worktreeDirectory == "/global/trees")
    #expect(effective.branchPrefix == "kieran/")
  }

  @Test func aWhitespaceOverrideMeansNone() {
    // The sheet stores a lone space to opt a project out of a global
    // prefix; it must not end up in the branch name.
    let effective = ProjectSettings(branchPrefix: " ").effective(defaults: defaults)
    #expect(effective.branchPrefix == "")
    #expect(effective.qualifiedBranch("tabs") == "tabs")
  }

  /// The worktree fields have no other spelling for "none", so a blank one
  /// keeps the override it is; a project pinned to no prefix while the
  /// global has one used to go back to following the global on the next load.
  @Test func aBlankWorktreeFieldDecodesAsTheOverrideToNone() throws {
    let json = Data(
      #"{ "worktreeDirectory": "", "branchPrefix": "", "defaultBranch": "", "postCreateHook": "" }"#
        .utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)

    #expect(settings.branchPrefix == "")
    #expect(settings.worktreeDirectory == "")
    #expect(settings.defaultBranch == "")
    #expect(settings.effective(defaults: defaults).branchPrefix == "", "not the global's team/")
  }

  /// A project pinned to no prefix has to survive being exported, committed
  /// and read by someone whose own global has one, or the team gets the
  /// opposite of what was shared.
  @Test func aBlankOverrideSurvivesAnExportAndTheFileItIsWrittenTo() throws {
    let repository = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-export-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: repository) }

    let exported = SharedProjectSettings(exporting: ProjectSettings(branchPrefix: ""))
    #expect(exported.branchPrefix == "")
    try exported.write(to: repository)

    let read = try #require(try SharedProjectSettings.load(from: repository))
    #expect(read.branchPrefix == "")
    // The reader leaves it alone, so the file's answer stands over a global
    // that has a prefix of its own.
    let inEffect = ProjectSettings().layered(over: read).effective(defaults: defaults)
    #expect(inEffect.branchPrefix == "")
    #expect(inEffect.qualifiedBranch("tabs") == "tabs")
  }

  /// A field that spells "none" some other way reads `""` as noise, so an
  /// empty one keeps following the global rather than overriding with
  /// nothing.
  @Test func aBlankFieldWithASentinelOfItsOwnStaysNoOverride() throws {
    let json = Data(#"{ "preferredAgentID": "", "defaultShell": "", "iconGlyph": "" }"#.utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)

    #expect(settings.preferredAgentID == nil)
    #expect(settings.defaultShell == nil)
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
    #expect(settings.effective(defaults: defaults).branchPrefix == "")
  }
}

@Suite
struct ShellCatalogueTests {
  @Test func theProjectOverrideWinsAndLoginMeansTheLoginShell() {
    #expect(ShellCatalogue.effectivePath(global: nil, override: nil) == nil)
    #expect(ShellCatalogue.effectivePath(global: "/bin/bash", override: nil) == "/bin/bash")
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: "/opt/homebrew/bin/fish")
        == "/opt/homebrew/bin/fish")
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: ShellCatalogue.loginShellID)
        == nil, "a project can step back to $SHELL")
    #expect(ShellCatalogue.effectivePath(global: "", override: nil) == nil)
  }

  @Test func theCustomIdResolvesToTheTypedPathOrToTheLoginShellWhenBlank() {
    let custom = ShellCatalogue.customID
    #expect(
      ShellCatalogue.effectivePath(global: custom, override: nil, customPath: " /opt/nu ")
        == "/opt/nu")
    #expect(ShellCatalogue.effectivePath(global: custom, override: nil, customPath: "  ") == nil)
    #expect(ShellCatalogue.effectivePath(global: custom, override: nil) == nil)
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: custom, customPath: "/opt/nu")
        == "/opt/nu", "a project can pick the custom path over a global shell")
    #expect(
      ShellCatalogue.effectivePath(global: custom, override: "/bin/bash", customPath: "/opt/nu")
        == "/bin/bash")
  }

  @Test func theLoginShellFallsBackToZshWhenTheEnvironmentHasNone() {
    #expect(ShellCatalogue.loginShellPath(environment: ["SHELL": "/bin/bash"]) == "/bin/bash")
    #expect(ShellCatalogue.loginShellPath(environment: [:]) == "/bin/zsh")
    #expect(ShellCatalogue.loginShellPath(environment: ["SHELL": ""]) == "/bin/zsh")
  }

  @Test func aWorkspaceResolvesAProjectsShellThroughItsOverride() {
    var workspace = Workspace()
    workspace.defaultShell = "/bin/bash"
    let plain = Project(path: URL(fileURLWithPath: "/repos/a"))
    let fish = Project(
      path: URL(fileURLWithPath: "/repos/b"),
      settings: ProjectSettings(defaultShell: "/usr/local/bin/fish"))
    let login = Project(
      path: URL(fileURLWithPath: "/repos/c"),
      settings: ProjectSettings(defaultShell: ShellCatalogue.loginShellID))
    #expect(workspace.defaultShell(for: plain) == "/bin/bash")
    #expect(workspace.defaultShell(for: fish) == "/usr/local/bin/fish")
    #expect(workspace.defaultShell(for: login) == nil)

    workspace.defaultShell = ShellCatalogue.customID
    workspace.customShellPath = "/opt/homebrew/bin/nu"
    #expect(workspace.defaultShell(for: plain) == "/opt/homebrew/bin/nu")
    #expect(workspace.defaultShell(for: fish) == "/usr/local/bin/fish")
  }
}

@Suite
struct EditorCatalogueTests {
  @Test func noneAndEmptyMeanNoEditor() {
    #expect(EditorCatalogue.effectiveID(nil) == nil)
    #expect(EditorCatalogue.effectiveID("") == nil)
    #expect(EditorCatalogue.effectiveID(EditorCatalogue.noneID) == nil)
    #expect(EditorCatalogue.effectiveID("vscode") == "vscode")
    #expect(EditorCatalogue.editor("vscode")?.bundleIdentifier == "com.microsoft.VSCode")
    #expect(EditorCatalogue.editor("nvim")?.kind == .terminal)
  }

  @Test func idsAreUnique() {
    let ids = EditorCatalogue.editors.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(EditorCatalogue.noneID) && !ids.contains(EditorCatalogue.customID))
  }

  @Test func theCustomTemplateGetsTheQuotedPathWhereThePlaceholderIs() {
    let path = URL(fileURLWithPath: "/Users/me/My Work/repo")
    #expect(
      EditorCatalogue.customCommandLine("code-insiders {path}", path: path)
        == "code-insiders '/Users/me/My Work/repo'")
    #expect(
      EditorCatalogue.customCommandLine("  micro  ", path: path)
        == "micro '/Users/me/My Work/repo'",
      "no placeholder: the path is appended")
    #expect(EditorCatalogue.customCommandLine("  ", path: path) == nil)
    #expect(
      EditorCatalogue.customCommandLine("open -a X {path} && echo {path}", path: path)
        == "open -a X '/Users/me/My Work/repo' && echo '/Users/me/My Work/repo'")
  }
}

@Suite
struct ProjectIconTests {
  @Test func aGlyphIsASymbolNameOrNothing() {
    #expect(ProjectIcon.kind(of: nil) == .folder)
    #expect(ProjectIcon.kind(of: "") == .folder)
    #expect(ProjectIcon.kind(of: "  ") == .folder)
    #expect(ProjectIcon.kind(of: "hammer") == .symbol("hammer"))
    #expect(ProjectIcon.kind(of: " hammer ") == .symbol("hammer"))
    #expect(ProjectIcon.kind(of: "not.a.symbol") == .folder, "only the curated list is drawn")
    #expect(
      ProjectIcon.kind(of: "🚀") == .folder,
      "an emoji a build that offered them stored draws the folder, not a blank")
  }

  @Test func tintsOutsideTheThemeAreNone() {
    #expect(ProjectIcon.validTint(nil) == nil)
    #expect(ProjectIcon.validTint(-1) == nil)
    #expect(ProjectIcon.validTint(16) == nil)
    #expect(ProjectIcon.validTint(0) == 0)
    #expect(ProjectIcon.validTint(15) == 15)
    #expect(ProjectSettings(iconTint: 40).iconTint == nil)
  }

  @Test func theCuratedSymbolsAreDistinctAndPlain() {
    #expect(Set(ProjectIcon.symbols).count == ProjectIcon.symbols.count)
    #expect(ProjectIcon.symbols.allSatisfy { $0.unicodeScalars.allSatisfy(\.isASCII) })
  }

  @Test func everySymbolIsInOneNamedGroup() {
    let groups = ProjectIcon.symbolGroups
    #expect(!groups.isEmpty)
    #expect(groups.allSatisfy { !$0.name.isEmpty && !$0.glyphs.isEmpty })
    #expect(Set(groups.map(\.name)).count == groups.count)
    #expect(
      groups.first?.glyphs.first == "folder",
      "the folder is the first cell, and picking it is what clears the glyph")
  }

  @Test func onlyASymbolNameCountsAsAGlyph() {
    #expect(ProjectIcon.symbolName("hammer") == "hammer")
    #expect(ProjectIcon.symbolName("  hammer  ") == "hammer")
    #expect(
      ProjectIcon.symbolName("sparkle.magnifyingglass") == "sparkle.magnifyingglass",
      "a name this build does not carry may still be one a teammate's build draws")
    #expect(ProjectIcon.symbolName("🚀") == nil, "no build draws an emoji any more")
    #expect(ProjectIcon.symbolName("") == nil)
    #expect(ProjectIcon.symbolName(nil) == nil)
  }

  @Test func everySearchWordNamesASymbolStillInThePalette() {
    let offered = Set(ProjectIcon.symbols)
    for name in ProjectIcon.searchWords.keys {
      #expect(offered.contains(name), "\(name) has search words but is not in the palette")
    }
    #expect(
      ProjectIcon.searchWords.values.allSatisfy { $0 == $0.lowercased() },
      "the query is lowercased before it is matched, so the words must be too")
  }

  @Test func aSearchNeverLeavesAGroupEmptyOrAddsToOne() {
    let source = Dictionary(
      uniqueKeysWithValues: ProjectIcon.symbolGroups.map { ($0.name, Set($0.glyphs)) })
    for query in ["", " ", "a", "e.", "folder", "Infra", "git", "zzz", "...", "1"] {
      for group in ProjectIcon.symbolGroups(matching: query) {
        // A group with no symbols under it draws a heading over nothing, and
        // the row of jumps takes its first symbol as the button to press.
        #expect(!group.glyphs.isEmpty, "\(query) left \(group.name) empty")
        #expect(
          Set(group.glyphs).isSubset(of: source[group.name] ?? []),
          "\(query) put a symbol in \(group.name) that is not one of its own")
      }
    }
  }

  @Test func searchingFindsASymbolByWhatItIsUsedFor() {
    func found(_ query: String) -> [String] {
      ProjectIcon.symbolGroups(matching: query).flatMap(\.glyphs)
    }
    #expect(found("database").contains("cylinder"))
    #expect(found("git").contains("arrow.triangle.branch"))
    #expect(found("docker").contains("shippingbox"))
    #expect(found("shell").contains("terminal"))
    #expect(found("bug").contains("ladybug"))
    #expect(found("cron").contains("clock"))
    #expect(found("SEARCH").contains("magnifyingglass"), "the query is folded, not the words")
  }

  @Test func searchingNarrowsAGroupToItsMatchesAndDropsTheRest() {
    #expect(ProjectIcon.symbolGroups(matching: "  ").count == ProjectIcon.symbolGroups.count)
    let folders = ProjectIcon.symbolGroups(matching: "folder")
    #expect(folders.allSatisfy { $0.glyphs.allSatisfy { $0.contains("folder") } })
    #expect(folders.flatMap(\.glyphs).contains("folder.fill"))
    let named = ProjectIcon.symbolGroups(matching: "Animals")
    #expect(named.count == 1)
    #expect(
      named.first?.glyphs.count
        == ProjectIcon.symbolGroups.first { $0.name == "Animals" }?.glyphs.count,
      "a group named outright keeps all of its symbols")
    #expect(ProjectIcon.symbolGroups(matching: "zzz").isEmpty)
  }
}

@Suite
struct WorktreeSettingsExpansionTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/repo"))

  @Test func tildeExpandsToTheHomeDirectory() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    #expect(
      WorktreeSettings(worktreeDirectory: "~/trees").worktreeContainer(for: project).path
        == "\(home)/trees")
    #expect(WorktreeSettings(worktreeDirectory: "~").worktreeContainer(for: project).path == home)
  }

  @Test func projectPlaceholderWorksInAbsolutePaths() {
    let settings = WorktreeSettings(worktreeDirectory: "/srv/trees/{project}")
    #expect(settings.worktreeContainer(for: project).path == "/srv/trees/repo")
  }

  @Test func aTildeInTheMiddleIsNotExpanded() {
    let settings = WorktreeSettings(worktreeDirectory: "odd~name")
    #expect(settings.worktreeContainer(for: project).path == "/w/repo/odd~name")
  }
}

/// The two listing settings resolve project-over-global like the rest; the
/// forms edit the override, and every reader goes through these.
@Suite
struct WorktreeListingResolutionTests {
  private func project(
    order: WorktreeSortOrder? = nil, activeFirst: Bool? = nil
  ) -> Project {
    var project = Project(path: URL(fileURLWithPath: "/w/demo"))
    project.settings = ProjectSettings(
      worktreeSortOrder: order, showsActiveWorktreesFirst: activeFirst)
    return project
  }

  @Test func aProjectWithNoOverrideFollowsTheGlobal() {
    var workspace = Workspace()
    workspace.worktreeSortOrder = .createdOldestFirst
    workspace.showsActiveWorktreesFirst = true

    #expect(workspace.worktreeSortOrder(for: project()) == .createdOldestFirst)
    #expect(workspace.showsActiveWorktreesFirst(for: project()))
  }

  @Test func aProjectsOwnChoiceWins() {
    var workspace = Workspace()
    workspace.worktreeSortOrder = .createdOldestFirst
    workspace.showsActiveWorktreesFirst = true
    let overridden = project(order: .committedNewestFirst, activeFirst: false)

    #expect(workspace.worktreeSortOrder(for: overridden) == .committedNewestFirst)
    #expect(!workspace.showsActiveWorktreesFirst(for: overridden))
  }

  /// An override that says "off" is not the same as no override: without
  /// this, turning the global on would drag every project with it.
  @Test func anOverrideThatMatchesTheOldGlobalStillHolds() {
    var workspace = Workspace()
    let overridden = project(order: .alphabetical, activeFirst: false)
    workspace.worktreeSortOrder = .createdNewestFirst
    workspace.showsActiveWorktreesFirst = true

    #expect(workspace.worktreeSortOrder(for: overridden) == .alphabetical)
    #expect(!workspace.showsActiveWorktreesFirst(for: overridden))
  }
}

/// The picker in Settings > Worktrees and the override in Project Settings
/// are built off `allCases`, and its labels are the only thing a view test
/// would have caught: two orders sharing a label, or one added without one,
/// give a dropdown with rows the user cannot tell apart.
@Suite
struct WorktreeSortOrderLabelTests {
  @Test func everyOrderHasItsOwnLabel() {
    let labels = WorktreeSortOrder.allCases.map(\.displayName)
    #expect(Set(labels).count == labels.count, "two orders share a label")
    #expect(labels.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
  }

  /// Raw values are what the state file holds, so they have to stay
  /// distinct from each other and stable against a case being reordered.
  @Test func everyOrderHasItsOwnStoredName() {
    let stored = WorktreeSortOrder.allCases.map(\.rawValue)
    #expect(Set(stored).count == stored.count)
    #expect(WorktreeSortOrder(rawValue: "alphabetical") == .alphabetical)
    #expect(WorktreeSortOrder.default == .alphabetical)
  }
}
