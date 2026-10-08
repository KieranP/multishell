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
    isRepositoryList: Bool = true, isStopRequested: @escaping @Sendable () -> Bool = { false }
  ) throws -> [String] {
    let placer = WorktreeFilePlacer(
      placement, from: repository, to: worktree, isRepositoryList: isRepositoryList,
      isStopRequested: isStopRequested)
    let split = splitByContainment(Self.paths(in: listText), under: repository)
    var failures = isRepositoryList ? split.escapes : []
    var skipped = isRepositoryList ? [] : split.escapes.map(\.path)

    for path in split.contained.flatMap({ WorktreeFilePattern.expand($0, in: repository) }) {
      let outcome: WorktreeFilePlacer.Outcome
      do {
        outcome = try placer.place(path)
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

  /// On the spelling, before the disk, so `~/.aws.json` is refused rather
  /// than skipped for not existing under the repository. See settings.md.
  private static func splitByContainment(
    _ paths: [String], under repository: URL
  ) -> (contained: [String], escapes: [WorktreeFileFailure.PathFailure]) {
    var contained: [String] = []
    var escapes: [WorktreeFileFailure.PathFailure] = []
    for path in paths {
      if RepositoryContainment.holds(listedPath: path, under: repository) {
        contained.append(path)
      } else {
        escapes.append(
          WorktreeFileFailure.PathFailure(path: path, underlying: WorktreeFileEscape()))
      }
    }
    return (contained, escapes)
  }
}
