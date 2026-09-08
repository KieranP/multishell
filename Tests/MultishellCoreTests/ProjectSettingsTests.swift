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

  @Test func legacyEmptyStringsDecodeAsNoOverride() throws {
    let json = Data(
      #"{ "worktreeDirectory": "./.worktrees", "branchPrefix": "", "postCreateHook": "", "postDeleteHook": "" }"#
        .utf8)
    let settings = try JSONDecoder().decode(ProjectSettings.self, from: json)
    #expect(settings.worktreeDirectory == "./.worktrees")
    #expect(settings.branchPrefix == nil)
    #expect(settings.effective(defaults: defaults).branchPrefix == "team/")
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
  @Test func aGlyphIsAnEmojiASymbolNameOrNothing() {
    #expect(ProjectIcon.kind(of: nil) == .folder)
    #expect(ProjectIcon.kind(of: "") == .folder)
    #expect(ProjectIcon.kind(of: "  ") == .folder)
    #expect(ProjectIcon.kind(of: "🚀") == .emoji("🚀"))
    #expect(ProjectIcon.kind(of: " 🚀🔥 ") == .emoji("🚀"), "one grapheme, whatever was pasted")
    #expect(ProjectIcon.kind(of: "👩‍💻") == .emoji("👩‍💻"), "a joined sequence is one grapheme")
    #expect(ProjectIcon.kind(of: "hammer") == .symbol("hammer"))
    #expect(ProjectIcon.kind(of: "not.a.symbol") == .folder, "only the curated list is drawn")
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
