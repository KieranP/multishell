import Foundation

/// A tab of either kind, as a group's strip lists them side by side. Both
/// kinds draw their ids from one space, so a group names either by id.
public enum WorkspaceTab: Identifiable, Hashable, Sendable {
  case file(FileTab)
  case terminal(TerminalTab)

  /// Where a dragged tab of either kind lands beside the tab or group it was
  /// dropped on. Nested because SwiftUI has a `TabPlacement` a view would clash with.
  public enum Placement: Codable, Equatable, Sendable {
    case after
    case before
  }

  public var id: UUID {
    switch self {
    case .file(let tab): tab.id
    case .terminal(let tab): tab.id
    }
  }

  public var worktreeID: Worktree.ID {
    switch self {
    case .file(let tab): tab.worktreeID
    case .terminal(let tab): tab.worktreeID
    }
  }

  public var groupID: TabGroup.ID {
    switch self {
    case .file(let tab): tab.groupID
    case .terminal(let tab): tab.groupID
    }
  }

  public var fileTab: FileTab? {
    if case .file(let tab) = self { tab } else { nil }
  }
}
