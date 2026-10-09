import Foundation
import MultishellCore

/// One list's run of `WorktreeFiles.place`: where each expanded path comes
/// from and goes, and how far an entry may reach.
struct WorktreeFilePlacer {
  enum Outcome {
    case done
    case failed(WorktreeFileFailure.PathFailure)
    case skipped
  }

  private let placement: WorktreeFilePlacement
  private let repository: URL
  private let worktree: URL
  private let isRepositoryList: Bool
  private let isStopRequested: @Sendable () -> Bool
  private let resolvedRepository: URL
  private let resolvedWorktree: URL

  init(
    _ placement: WorktreeFilePlacement, from repository: URL, to worktree: URL,
    isRepositoryList: Bool, isStopRequested: @escaping @Sendable () -> Bool
  ) {
    self.placement = placement
    self.repository = repository
    self.worktree = worktree
    self.isRepositoryList = isRepositoryList
    self.isStopRequested = isStopRequested
    resolvedRepository = repository.resolvingSymlinksInPath()
    resolvedWorktree = worktree.resolvingSymlinksInPath()
  }

  /// One expanded path. Throws only a stop, any other error being that
  /// path's failure.
  func place(_ path: String) throws(WorktreeFileStopped) -> Outcome {
    guard !isStopRequested() else { throw WorktreeFileStopped() }
    let manager = FileManager.default
    let source = repository.appendingPathComponent(path)
    let destination = worktree.appendingPathComponent(path)
    // A path the repository does not have is the quiet case and comes
    // first, so `.env` on a checkout without one is not an escape.
    guard manager.fileExists(atPath: source.path) else { return .done }
    let landsInWorktree = Self.isInside(
      destination.deletingLastPathComponent().splitAtDeepestExisting().existing,
      under: resolvedWorktree)
    if isRepositoryList {
      // Each end as on disk, the source itself included: `copyItem` carries
      // a symlink rather than following it. See Docs/design/hooks.md.
      guard landsInWorktree,
        Self.isInside(source.deletingLastPathComponent(), under: resolvedRepository),
        Self.isInside(source, under: resolvedRepository)
      else {
        return .failed(
          WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
      }
    } else if !landsInWorktree {
      // The destination is mirrored from the entry rather than asked for,
      // so a user's own entry pointing out places nothing, and is named.
      return .skipped
    }
    guard !destination.hasEntryOnDisk else { return .done }
    do {
      try manager.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      switch placement {
      case .link:
        // The repository's path unresolved, so the link reads as the
        // checkout the user sees. Absolute, as git records one.
        try manager.createSymbolicLink(at: destination, withDestinationURL: source)
      case .copy:
        try WorktreeFileCopy.copy(source, to: destination, isStopRequested: isStopRequested)
      }
    } catch let stop as WorktreeFileStopped {
      throw stop
    } catch {
      return .failed(WorktreeFileFailure.PathFailure(path: path, underlying: error))
    }
    return .done
  }

  /// Whether `url`, symlinks resolved, is `base` or something under it.
  private static func isInside(_ url: URL, under base: URL) -> Bool {
    url.resolvingSymlinksInPath().pathComponents(under: base) != nil
  }
}
