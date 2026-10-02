import Foundation
import MultishellCore

/// What each live terminal is doing, and who clears what. Runtime only; see
/// Docs/design/agents.md.
public struct SessionStates: Equatable, Sendable {
  public enum Key: Hashable, Sendable {
    case session(TerminalSession.ID)
    /// A report that named only a directory: a hook fired from another
    /// terminal in that worktree.
    case worktree(Worktree.ID)
  }

  private(set) var entries: [Key: Entry] = [:]
  /// The id of each pane's own conversation, from an agent that runs a
  /// worker as one of its own. Apart from `entries`, which go on a clear.
  var ownConversationIDs: [Key: String] = [:]

  /// An entry with nothing left in it goes, so `isEmpty` and `==` read true.
  mutating func update(_ key: Key, _ change: (inout Entry) -> Void) {
    var entry = entries[key] ?? Entry()
    change(&entry)
    entries[key] = entry.isEmpty ? nil : entry
  }

  /// Keeps the keys a subset of what exists: live shells and known
  /// worktrees. Done for a dead shell is nothing to look at.
  mutating func retain(sessions: Set<TerminalSession.ID>, worktrees: Set<Worktree.ID>) {
    func exists(_ key: Key) -> Bool {
      switch key {
      case .session(let id): sessions.contains(id)
      case .worktree(let id): worktrees.contains(id)
      }
    }
    entries = entries.filter { exists($0.key) }
    ownConversationIDs = ownConversationIDs.filter { exists($0.key) }
  }
}
