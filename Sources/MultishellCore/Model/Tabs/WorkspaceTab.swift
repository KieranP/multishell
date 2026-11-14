import Foundation

/// A tab of any kind, as a group's strip lists them side by side. Every kind
/// draws its ids from one space, so a group names any by id.
public enum WorkspaceTab: Identifiable, Hashable, Sendable {
  case allChanges(AllChangesTab)
  case file(FileTab)
  case terminal(TerminalTab)

  /// Where a dragged tab of any kind lands beside the tab or group it was
  /// dropped on. Nested because SwiftUI has a `TabPlacement` a view would clash with.
  public enum Placement: Codable, Equatable, Sendable {
    case after
    case before
  }

  public var id: UUID {
    switch self {
    case .allChanges(let tab): tab.id
    case .file(let tab): tab.id
    case .terminal(let tab): tab.id
    }
  }

  public var worktreeID: Worktree.ID {
    switch self {
    case .allChanges(let tab): tab.worktreeID
    case .file(let tab): tab.worktreeID
    case .terminal(let tab): tab.worktreeID
    }
  }

  public var groupID: TabGroup.ID {
    switch self {
    case .allChanges(let tab): tab.groupID
    case .file(let tab): tab.groupID
    case .terminal(let tab): tab.groupID
    }
  }

  public var fileTab: FileTab? {
    if case .file(let tab) = self { tab } else { nil }
  }

  public var allChangesTab: AllChangesTab? {
    if case .allChanges(let tab) = self { tab } else { nil }
  }
}
