import MultishellCore

/// What each of a project's two file lists does: a link shares the
/// repository's file, a copy duplicates it. Case order is run order.
public enum WorktreePlacement: CaseIterable, Sendable {
  case link
  case copy

  /// The list this placement takes its paths from, so the two lists are
  /// paired with what they do in one place rather than at each caller.
  public func paths(in settings: ProjectSettings) -> String {
    switch self {
    case .link: settings.linkedPaths
    case .copy: settings.copiedPaths
    }
  }
}
