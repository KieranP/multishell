import Foundation
import TestScratch
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
    #expect(settings.effective(defaults: defaults).branchPrefix == "", "not the global's team/")
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
    let inEffect = ProjectSettings().layered(over: read).effective(defaults: defaults)
    #expect(inEffect.branchPrefix == "")
    #expect(inEffect.qualifiedBranch("tabs") == "tabs")
  }

  /// A field with its own spelling for "none" reads `""` as noise and keeps
  /// following the global.
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
      groups.first?.glyphs.first == ProjectIcon.folderSymbol,
      "the folder is the first cell, and picking it is what goes back to no glyph")
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

/// What a repository's own `.multishell.json` may name on the reader's disk:
/// only what is under the checkout; see Docs/design/settings.md.
@Suite
struct RepositoryContainmentTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  private func holdsDirectory(_ directory: String) -> Bool {
    RepositoryContainment.holds(
      directory: WorktreeSettings(worktreeDirectory: directory).worktreeContainer(for: project),
      under: project.path)
  }

  @Test func aDirectoryUnderTheCheckoutStands() {
    #expect(holdsDirectory(".worktrees"))
    #expect(holdsDirectory("trees/{project}"))
    #expect(holdsDirectory("  .worktrees  "))
  }

  @Test func everyDirectoryOutsideTheCheckoutIsRefused() {
    let outside = [
      "~/.claude/skills", "~", "/tmp/trees", "/", "../{project}-worktrees", "..",
      ".worktrees/../..", "", "   ", ".", "./",
    ]
    for directory in outside {
      #expect(!holdsDirectory(directory), "\(directory.debugDescription)")
    }
  }

  @Test func aCommittedSymlinkCannotCarryTheDirectoryOutOfTheCheckout() throws {
    let root = try Scratch.directory("confined")
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = root.appendingPathComponent("repo", isDirectory: true)
    let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: repository.appendingPathComponent("trees"), withDestinationURL: elsewhere)
    #expect(
      !RepositoryContainment.holds(
        directory: repository.appendingPathComponent("trees"), under: repository))
  }

  @Test func theRefusedDirectoryLeavesTheReadersOwnValueStanding() {
    var shared = SharedProjectSettings(worktreeDirectory: "~/.claude/skills", branchPrefix: "team/")
    shared = shared.confined(to: project)
    #expect(shared.worktreeDirectory == nil)
    #expect(shared.branchPrefix == "team/", "only the one field is dropped")

    let layered = ProjectSettings().layered(over: shared)
    let defaults = WorktreeSettings(worktreeDirectory: "/global/trees")
    #expect(layered.effective(defaults: defaults).worktreeDirectory == "/global/trees")
  }

  @Test func aDirectoryUnderTheCheckoutSurvivesConfinement() {
    let shared = SharedProjectSettings(worktreeDirectory: ".worktrees").confined(to: project)
    #expect(shared.worktreeDirectory == ".worktrees")
  }

  @Test func aListedPathUnderTheCheckoutStands() {
    for path in [
      ".env", "config/local.yml", "a/../b", "./vendor", "*.env", "a/b/../c", "  .env  ",
      "deep/nested/path/file.txt", "cost$.txt", "src/a$b/c",
    ] {
      #expect(
        RepositoryContainment.holds(listedPath: path, under: project.path),
        "\(path.debugDescription)")
    }
  }

  @Test func aListedPathReachingOutsideTheCheckoutIsRefused() {
    let outside = [
      "~/.ssh/id_ed25519", "~", "~root/.ssh", "/Users/dev/.ssh/id_ed25519", "/etc/passwd", "/",
      "$HOME/.aws.json", "${HOME}/.aws.json", "../secrets", "a/../../b", "..", "../",
      "a/b/../../../c", "./../x", ".", "./", "", "   ", "a/../..",
    ]
    for path in outside {
      #expect(
        !RepositoryContainment.holds(listedPath: path, under: project.path),
        "\(path.debugDescription)")
    }
  }

  @Test func onlyTheReachingEntriesAreDroppedFromAList() {
    let shared = SharedProjectSettings(
      linkedPaths: "vendor\n~/.ssh/id_ed25519\nnode_modules",
      copiedPaths: "/etc/passwd\n../../.aws/credentials"
    ).confined(to: project)
    #expect(shared.linkedPaths == "vendor\nnode_modules")
    #expect(shared.copiedPaths == nil, "a list of nothing but escapes leaves the reader's standing")
  }

  @Test func aListWithNothingToDropComesBackAsItWasWritten() {
    let list = "# what the build needs\nvendor\n\nnode_modules"
    let shared = SharedProjectSettings(linkedPaths: list, copiedPaths: ".env")
      .confined(to: project)
    #expect(shared.linkedPaths == list, "export writes this text back over the file")
    #expect(shared.copiedPaths == ".env")
  }

  @Test func aKeyLinkedFromHomeNeverReachesTheReadersWorktree() {
    let shared = SharedProjectSettings(
      linkedPaths: "~/.ssh/id_ed25519", copiedPaths: "~/.aws/credentials")
    let layered = ProjectSettings().layered(over: shared.confined(to: project))
    #expect(layered.linkedPaths.isEmpty && layered.copiedPaths.isEmpty)
  }

  @Test func confiningLeavesTheDigestAloneSoAHookAnswerStillHolds() throws {
    let root = try Scratch.directory("confined-digest")
    defer { try? FileManager.default.removeItem(at: root) }
    try SharedProjectSettings(worktreeDirectory: "/tmp/trees", postCreateHook: "npm ci")
      .write(to: root)
    let read = try #require(try SharedProjectSettings.load(from: root))
    let confined = read.confined(to: Project(path: root))
    #expect(confined.digest == read.digest)
    #expect(confined.postCreateHook == "npm ci")
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

/// Both pickers are built off `allCases`, so two orders sharing a label, or
/// one added without one, give rows the user cannot tell apart.
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
