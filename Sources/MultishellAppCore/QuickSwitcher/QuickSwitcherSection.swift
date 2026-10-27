import MultishellCore

/// A titled run of quick switcher rows. The view words the title from the kind.
public struct QuickSwitcherSection: Identifiable, Equatable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// Agents asking something of the user, longest wait first.
    case waiting
    case recent
    /// Agents, worktrees, tabs and projects matching the text.
    case places
    /// Files of the selected worktree matching the text, by its name.
    case files(worktreeName: String)
    /// What changed in the selected worktree, by its name.
    case changedFiles(worktreeName: String)
    case commands
    case worktrees
    case tabs
    case agents(SessionState)
  }

  public let kind: Kind
  public let items: [QuickSwitcherItem]

  public var id: Kind { kind }
}
