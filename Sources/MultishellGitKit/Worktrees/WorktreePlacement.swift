import MultishellCore

/// A list as a create will place it: the paths in force, and whether the
/// repository listed them, which is what is held to the checkout (settings.md).
public struct WorktreeFileList: Sendable {
  public let placement: WorktreePlacement
  let paths: String
  let heldToRepository: Bool

  public init(placement: WorktreePlacement, paths: String, heldToRepository: Bool) {
    self.placement = placement
    self.paths = paths
    self.heldToRepository = heldToRepository
  }
}

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
