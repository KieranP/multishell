import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  /// Every repository has at least its main worktree, so an empty list is
  /// git failing quietly; taken as a result it drops every tab.
  public func list(_ project: Project) async throws -> [Worktree] {
    let worktrees = try await parsedList(in: project.path, projectID: project.id)
    guard !worktrees.isEmpty else {
      throw ProcessFailure.unreportedByGit(
        ["worktree", "list"], message: "git listed no worktrees for \(project.path.path)")
    }
    // Stats, each of which a dead mount holds; see worktrees.md.
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

  /// git records no creation time, so the sidebar sorts by the directory's
  /// birth time, stamped on here to keep the parser off the filesystem.
  private static func datedByDirectory(_ worktree: Worktree) -> Worktree {
    var dated = worktree
    dated.createdAt = try? worktree.path.resourceValues(forKeys: [.creationDateKey]).creationDate
    return dated
  }

  /// The main worktree of the repository `url` is in, from anywhere in it,
  /// which identifies a project so a subdirectory does not become a second.
  public func mainWorktreePath(containing url: URL) async throws -> URL {
    guard let main = try await parsedList(in: url, projectID: "").first else {
      throw ProcessFailure.unreportedByGit(
        ["worktree", "list"], message: "no worktree listed for \(url.path)")
    }
    return main.path
  }

  /// An answer that proves nothing, unreadable or empty, counts as listed:
  /// the caller deletes the branch next. See Docs/design/worktrees.md.
  func isListed(_ path: URL, in project: Project) async -> Bool {
    guard let listed = try? await parsedList(in: project.path, projectID: project.id),
      !listed.isEmpty
    else { return true }
    return await runOnDispatch {
      let wanted = Self.pathAsGitLists(path)
      return listed.contains { Self.pathAsGitLists($0.path) == wanted }
    }
  }
}
