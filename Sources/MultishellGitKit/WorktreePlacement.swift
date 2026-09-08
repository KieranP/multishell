import MultishellCore

/// What one of a project's two file lists does with the paths it names:
/// a link shares the repository's file, a copy duplicates it.
///
/// The case order is the order the lists run in, links before copies, and
/// what a caller iterates to show one stage per list a project has filled
/// in. See `WorktreeFiles`.
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
