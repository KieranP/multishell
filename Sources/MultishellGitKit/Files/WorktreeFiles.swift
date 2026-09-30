import Foundation
import MultishellCore

/// Puts a project's listed files into each new worktree, for what git does
/// not carry. One path per line, `*` and `?` allowed; see hooks.md.
public enum WorktreeFiles {
  /// The paths in a list, without blanks, comments or repeats. `place`
  /// judges what is in reach, against the disk.
  public static func paths(in listText: String) -> [String] {
    LineList.entries(in: listText).uniqued(by: \.self)
  }

  /// Links or copies each listed path, placing all it can before throwing, and
  /// returns a user's own entries that name somewhere else; see hooks.md.
  @discardableResult
  static func place(
    _ listText: String, as placement: WorktreeFilePlacement, from repository: URL, to worktree: URL,
    heldToRepository: Bool = true, isStopped: @Sendable () -> Bool = { false }
  ) throws -> [String] {
    let bases = (
      repository: repository.resolvingSymlinksInPath(), worktree: worktree.resolvingSymlinksInPath()
    )
    let split = splitByContainment(Self.paths(in: listText), under: repository)
    var failures = heldToRepository ? split.escapes : []
    var skipped = heldToRepository ? [] : split.escapes.map(\.path)

    for path in split.listed.flatMap({ WorktreeFilePattern.expand($0, in: repository) }) {
      let outcome: PathOutcome
      do {
        outcome = try placePath(
          path, as: placement, from: repository, to: worktree, resolved: bases,
          heldToRepository: heldToRepository, isStopped: isStopped)
      } catch {
        throw WorktreeFileStopped(failures: failures, skipped: skipped)
      }
      switch outcome {
      case .done: break
      case .failed(let failure): failures.append(failure)
      case .skipped: skipped.append(path)
      }
    }
    guard failures.isEmpty else {
      throw WorktreeFileFailure(placement: placement, failures: failures, skipped: skipped)
    }
    return skipped
  }

  private enum PathOutcome {
    case done
    case failed(WorktreeFileFailure.PathFailure)
    case skipped
  }

  /// One expanded path. Throws only a stop, any other error being that
  /// path's failure.
  private static func placePath(
    _ path: String, as placement: WorktreeFilePlacement, from repository: URL, to worktree: URL,
    resolved bases: (repository: URL, worktree: URL), heldToRepository: Bool,
    isStopped: () -> Bool
  ) throws(WorktreeFileStopped) -> PathOutcome {
    guard !isStopped() else { throw WorktreeFileStopped() }
    let manager = FileManager.default
    let source = repository.appendingPathComponent(path)
    let destination = worktree.appendingPathComponent(path)
    // A path the repository does not have is the quiet case and comes
    // first, so `.env` on a checkout without one is not an escape.
    guard manager.fileExists(atPath: source.path) else { return .done }
    let landsInWorktree = Self.isInside(
      destination.deletingLastPathComponent().splitAtDeepestExisting().existing,
      under: bases.worktree)
    if heldToRepository {
      // Each end as on disk, the source itself included: `copyItem` carries
      // a symlink rather than following it. See Docs/design/hooks.md.
      guard landsInWorktree,
        Self.isInside(source.deletingLastPathComponent(), under: bases.repository),
        Self.isInside(source, under: bases.repository)
      else {
        return .failed(
          WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
      }
    } else if !landsInWorktree {
      // The destination is mirrored from the entry rather than asked for,
      // so a user's own entry pointing out places nothing, and is named.
      return .skipped
    }
    guard !Self.isPresent(destination) else { return .done }
    do {
      try manager.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      switch placement {
      case .link:
        // The repository's path unresolved, so the link reads as the
        // checkout the user sees. Absolute, as git records one.
        try manager.createSymbolicLink(at: destination, withDestinationURL: source)
      case .copy:
        try WorktreeFileCopy.copy(source, to: destination, isStopped: isStopped)
      }
    } catch let stop as WorktreeFileStopped {
      throw stop
    } catch {
      return .failed(WorktreeFileFailure.PathFailure(path: path, underlying: error))
    }
    return .done
  }

  /// On the spelling, before the disk, so `~/.aws.json` is refused rather
  /// than skipped for not existing under the repository. See settings.md.
  private static func splitByContainment(
    _ paths: [String], under repository: URL
  ) -> (listed: [String], escapes: [WorktreeFileFailure.PathFailure]) {
    var listed: [String] = []
    var escapes: [WorktreeFileFailure.PathFailure] = []
    for path in paths {
      if RepositoryContainment.holds(listedPath: path, under: repository) {
        listed.append(path)
      } else {
        escapes.append(
          WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
      }
    }
    return (listed, escapes)
  }

  /// Whether anything is at `url`, a symlink included, without asking where
  /// it leads: the question is what is in the way, not what resolves.
  private static func isPresent(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
  }

  /// Whether `url`, symlinks resolved, is `base` or something under it.
  private static func isInside(_ url: URL, under base: URL) -> Bool {
    url.resolvingSymlinksInPath().pathComponents(under: base) != nil
  }
}
