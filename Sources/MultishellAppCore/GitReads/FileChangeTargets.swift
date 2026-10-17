import Foundation
import MultishellCore

/// What one watcher tick calls for: a change in a project's git directory can
/// move any of its rows, and one in a worktree's files moves that row alone.
struct FileChangeTargets {
  /// What under `.git` can move a row; the rest, and any `.lock`, is a command's
  /// scratch. See Docs/design/worktrees.md.
  private static let gitEntriesThatMoveRows: Set<String> = [
    "HEAD", "config", "config.worktree", "index", "info", "modules", "packed-refs", "reftable",
    "refs", "worktrees",
  ]

  /// The path of the worktree itself, which a dropped batch reports: it says
  /// nothing of which file changed.
  static let wholeWorktree = ""

  private(set) var projectsWithGitChanges: Set<Project.ID> = []
  /// Any change under a project's git directory, scratch included, where its
  /// worktree records may have moved.
  private(set) var projectsWithGitDirectoryChanges: Set<Project.ID> = []
  /// The changes in each worktree's own files, as paths within it.
  private(set) var fileChangesByWorktree: [Worktree.ID: [String]] = [:]
  private(set) var projectsWithSharedSettingsChanges: Set<Project.ID> = []
  /// Worktrees one of whose `.gitignore` files changed.
  private(set) var worktreesWithIgnoreRuleChanges: Set<Worktree.ID> = []
  private(set) var hasThemeChanges = false

  init(
    changed: [URL],
    projects: [Project],
    gitDirectories: [Project.ID: URL],
    worktrees: [Worktree],
    themesDirectory: URL,
  ) {
    // Each path standardized once: an install reports thousands of directories,
    // and comparing URLs restandardized both sides of every pair.
    let gitBases = gitDirectories.map { StandardizedPath(id: $0.key, url: $0.value) }
    let worktreeBases = worktrees.map { StandardizedPath(id: $0.id, url: $0.path) }
    let projectBases = projects.map { StandardizedPath(id: $0.id, url: $0.path) }
    let themes = StandardizedPath(id: (), url: themesDirectory)
    for url in changed {
      let components = url.standardizedFileURL.pathComponents
      if themes.subpath(to: components) != nil {
        hasThemeChanges = true
        continue
      }
      for base in gitBases where base.subpath(to: components) != nil {
        projectsWithGitDirectoryChanges.insert(base.id)
      }
      let git = Self.deepest(holding: components, in: gitBases)
      // The deeper of the two holds it: `.git` sits in the main worktree, and a
      // bare repository's worktrees can sit in its git directory.
      let worktree = Self.deepest(holding: components, in: worktreeBases)
      if let git, git.subpath.count <= worktree?.subpath.count ?? .max {
        // Empty where a batch was dropped and every directory counts as changed.
        let movesRows = git.subpath.first.map(Self.gitEntriesThatMoveRows.contains) ?? true
        if movesRows, !Self.isGitScratch(git.subpath) { projectsWithGitChanges.insert(git.id) }
        continue
      }
      // An embedded repository, or a submodule never absorbed, keeps its `.git`
      // in the worktree, and the outer status writes its monitor's cookie there.
      if let worktree, let dotGit = worktree.subpath.firstIndex(of: ".git"),
        Self.isGitScratch(worktree.subpath[(dotGit + 1)...])
      {
        continue
      }
      if let worktree {
        fileChangesByWorktree[worktree.id, default: []].append(
          worktree.subpath.joined(separator: "/")
        )
        if worktree.subpath.last == ".gitignore" {
          worktreesWithIgnoreRuleChanges.insert(worktree.id)
        }
      }
      for project in projectBases
      where project.subpath(to: components) == [SharedProjectSettings.fileName] {
        projectsWithSharedSettingsChanges.insert(project.id)
      }
    }
  }

  /// A lock that may come to nothing, or git's file monitor answering a read:
  /// its cookies go under whichever git directory the read ran in.
  private static func isGitScratch(_ insideGitDirectory: ArraySlice<String>) -> Bool {
    insideGitDirectory.last?.hasSuffix(".lock") == true
      || insideGitDirectory.contains { $0.hasPrefix("fsmonitor--daemon") }
  }

  /// The deepest base holding `components`: a submodule added as a project
  /// keeps its git directory inside the outer project's.
  private static func deepest<ID>(
    holding components: [String],
    in bases: [StandardizedPath<ID>],
  ) -> (id: ID, subpath: ArraySlice<String>)? {
    var deepest: (id: ID, subpath: ArraySlice<String>)?
    for base in bases {
      guard let subpath = base.subpath(to: components),
        subpath.count < deepest?.subpath.count ?? .max
      else { continue }
      deepest = (base.id, subpath)
    }
    return deepest
  }

  func mayHaveChangedStatus(of worktree: Worktree) -> Bool {
    projectsWithGitChanges.contains(worktree.projectID)
      || fileChangesByWorktree[worktree.id] != nil
  }
}
