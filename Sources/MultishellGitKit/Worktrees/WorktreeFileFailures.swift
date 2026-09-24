import Foundation
import MultishellCore

/// Raised when a list could not be finished. The worktree exists and
/// everything else on the list is in it; only these paths are missing.
public struct WorktreeFileFailure: Error, CustomStringConvertible {
  public struct Item: Sendable {
    public let path: String
    public let underlying: any Error

    public init(path: String, underlying: any Error) {
      self.path = path
      self.underlying = underlying
    }
  }

  /// Which list it was, so what is said about it can say linked or copied.
  public let placement: WorktreePlacement
  public let items: [Item]
  /// Entries skipped for naming somewhere else, by any list, kept apart from
  /// `items`: the title says this list failed to place those.
  public let skippedEntries: [String]

  public init(placement: WorktreePlacement, items: [Item], skippedEntries: [String] = []) {
    self.placement = placement
    self.items = items
    self.skippedEntries = skippedEntries
  }

  public var description: String {
    items.map { "\($0.path): \($0.underlying.localizedDescription)" }.joined(separator: "\n")
  }

  /// With another list's entries that named somewhere else, so one message
  /// says both: a second would take the one alert or pane from the first.
  public func including(skipped entries: [String]) -> WorktreeFileFailure {
    WorktreeFileFailure(
      placement: placement, items: items, skippedEntries: skippedEntries + entries)
  }
}

/// The user stopped a list part way. What was placed stays, as a stopped
/// hook's work does; `failures` is what had already gone wrong, unexcused.
public struct WorktreeFilesStopped: Error {
  public let failures: [WorktreeFileFailure.Item]
  public let skipped: [WorktreeFileFailure.Item]

  init(
    failures: [WorktreeFileFailure.Item] = [], skipped: [WorktreeFileFailure.Item] = []
  ) {
    self.failures = failures
    self.skipped = skipped
  }
}

/// A listed path leading out of the repository or worktree, by `..` or a
/// symlinked folder. `LocalizedError`, to read as a sentence in the alert.
struct WorktreeFileEscape: LocalizedError {
  init() {}

  var errorDescription: String? {
    t("worktree-file.escape")
  }
}

/// A user's own list entries that name somewhere other than the repository,
/// said once the rest are placed and the hook has been let run.
public struct WorktreeFilesSkipped: Error {
  public let entries: [String]

  public init(entries: [String]) { self.entries = entries }
}
