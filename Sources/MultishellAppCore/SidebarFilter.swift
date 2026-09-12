import Foundation
import MultishellCore

/// What the sidebar shows for a filter string. A project matching keeps all
/// its worktrees; matching folds case and accents, never by the reader's
/// alphabet, branch and directory names not being their language.
public struct SidebarFilter: Sendable {
  public struct Entry: Equatable, Sendable {
    public let project: Project
    public let worktrees: [Worktree]
    public let forcedOpen: Bool
  }

  public let needle: String

  public init(_ text: String) {
    needle = text.trimmingCharacters(in: .whitespaces)
  }

  public var isActive: Bool { !needle.isEmpty }

  public func apply(to workspace: Workspace) -> [Entry] {
    workspace.projects.compactMap { project in
      let worktrees = workspace.worktrees(of: project.id)
      guard isActive else {
        return Entry(project: project, worktrees: worktrees, forcedOpen: false)
      }
      if project.name.foldedContains(needle) {
        return Entry(project: project, worktrees: worktrees, forcedOpen: true)
      }
      let matching = worktrees.filter {
        $0.name.foldedContains(needle) || workspace.displayName(of: $0).foldedContains(needle)
      }
      return matching.isEmpty ? nil : Entry(project: project, worktrees: matching, forcedOpen: true)
    }
  }
}
