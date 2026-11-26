import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  /// git records no creation time, so the sidebar sorts by the directory's
  /// birth time, stamped on here to keep the parser off the filesystem.
  private static func datedByDirectory(_ worktree: Worktree) -> Worktree {
    var dated = worktree
    dated.createdAt = try? worktree.path.resourceValues(forKeys: [.creationDateKey]).creationDate
    return dated
  }

  /// With its `.git` gone git walks up to an enclosing repository and lists that
  /// one's worktrees, whose replacing ours would drop every tab; see worktrees/sidebar.md.
  private static func namesItsOwnPath(_ worktrees: [Worktree], _ projectPath: URL) -> Bool {
    let own = projectPath.comparablePath.lowercased()
    return worktrees.contains { $0.path.comparablePath.lowercased() == own }
  }

  /// git 2.56 lists a submodule's checkout, or one made with `--separate-git-dir`,
  /// by its git directory: the project whose `.git` file names it is that checkout.
  private static func checkoutInPlaceOfGitDirectory(
    _ worktrees: [Worktree],
    _ projectPath: URL,
  ) -> [Worktree] {
    guard let main = worktrees.first, main.isPrimary, !main.isBare,
      let named = directoryNamed(
        inFile: projectPath.appendingPathComponent(".git"),
        relativeTo: projectPath,
        after: "gitdir: ",
      ),
      sameComparablePath(named, main.path)
    else { return worktrees }
    let checkout = Worktree(
      path: projectPath,
      projectID: main.projectID,
      head: main.head,
      branch: main.branch,
      isPrimary: true,
      isLocked: main.isLocked,
      isInitializing: main.isInitializing,
      createdAt: main.createdAt,
    )
    return [checkout] + worktrees.dropFirst()
  }

  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly; taken as a result it drops every tab.
  public func list(_ project: Project) async throws -> [Worktree] {
    let parsed = try await parsedList(in: project.path, projectID: project.id)
    guard !parsed.isEmpty else {
      throw ProcessFailure.unreportedByGit(
        ["worktree", "list"],
        message: "git listed no worktrees for \(project.path.path)",
      )
    }
    let projectPath = project.path
    // Stats, each of which a dead mount holds; see worktrees/line-count-badge.md.
    let named = await runOnDispatch { () -> [Worktree]? in
      let listed = Self.checkoutInPlaceOfGitDirectory(parsed, projectPath)
      return Self.namesItsOwnPath(listed, projectPath) ? listed : nil
    }
    guard let worktrees = named else {
      throw ProcessFailure.unreportedByGit(
        ["worktree", "list"],
        message: "git listed another repository's worktrees for \(projectPath.path)",
      )
    }
    return await runOnDispatch { worktrees.map(Self.datedByDirectory).map(Self.judgedInitializing) }
  }

  /// `-z` came in git 2.36, and an older one refuses the switch with 129; its
  /// newline form is read instead, at the cost of a path holding a newline.
  private func parsedList(in directory: URL, projectID: Project.ID) async throws -> [Worktree] {
    do {
      let output = try await runner.run(["worktree", "list", "--porcelain", "-z"], in: directory)
      return WorktreeListParser.parse(output, projectID: projectID)
    } catch let failure as ProcessFailure where failure.status == 129 {
      let output = try await runner.run(["worktree", "list", "--porcelain"], in: directory)
      return WorktreeListParser.parse(output, projectID: projectID, separator: "\n")
    }
  }

  /// The main worktree of the repository `url` is in, from anywhere in it,
  /// which identifies a project so a subdirectory does not become a second.
  public func mainWorktreePath(containing url: URL) async throws -> URL {
    guard let main = try await parsedList(in: url, projectID: "").first else {
      throw ProcessFailure.unreportedByGit(
        ["worktree", "list"],
        message: "no worktree listed for \(url.path)",
      )
    }
    // A checkout has a `.git`; only where the main entry has none is git asked
    // whether it listed the git directory in the checkout's place.
    let hasGitEntry = await runOnDispatch {
      main.path.appendingPathComponent(".git").hasEntryOnDisk
    }
    guard !main.isBare, !hasGitEntry,
      let output = await runner.output(
        ["rev-parse", Self.absolutePathsFlag, "--git-common-dir", "--show-toplevel"],
        in: url,
      )
    else { return main.path }
    let paths = Self.absolutePaths(in: output, from: url)
    let isGitDirectory = await runOnDispatch {
      paths.count == 2 && Self.sameComparablePath(paths[0], main.path)
    }
    return isGitDirectory ? paths[1] : main.path
  }

  /// An answer that proves nothing, unreadable or empty, counts as listed:
  /// the caller deletes the branch next. See Docs/design/worktrees/creating-and-removing.md.
  func isListed(_ path: URL, in project: Project, ignoringCase: Bool = false) async -> Bool {
    await listsWorktree(at: path, in: project, ignoringCase: ignoringCase) ?? true
  }

  /// `nil` where git's answer proves nothing, unreadable, empty or an enclosing
  /// repository's. `ignoringCase` as git matches a path under `core.ignorecase`, macOS's default.
  func listsWorktree(at path: URL, in project: Project, ignoringCase: Bool = false) async -> Bool? {
    guard let parsed = try? await parsedList(in: project.path, projectID: project.id),
      !parsed.isEmpty
    else { return nil }
    let projectPath = project.path
    return await runOnDispatch {
      let listed = Self.checkoutInPlaceOfGitDirectory(parsed, projectPath)
      guard Self.namesItsOwnPath(listed, projectPath) else { return nil }
      let spelling = { (url: URL) in
        ignoringCase ? Self.pathAsGitLists(url).lowercased() : Self.pathAsGitLists(url)
      }
      let wanted = spelling(path)
      return listed.contains { spelling($0.path) == wanted }
    }
  }
}
