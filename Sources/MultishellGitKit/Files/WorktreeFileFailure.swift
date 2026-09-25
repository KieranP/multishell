import Foundation

/// Raised when a list could not be finished. The worktree exists and
/// everything else on the list is in it; only these paths are missing.
public struct WorktreeFileFailure: Error, CustomStringConvertible {
  public struct Item: Sendable {
    public let path: String
    public let underlying: any Error
  }

  /// Which list it was, so what is said about it can say linked or copied.
  public let placement: WorktreeFilePlacement
  public let failures: [Item]
  /// Entries skipped for naming somewhere else, by any list, kept apart from
  /// `failures`: the title says this list failed to place those.
  public let skipped: [String]

  public init(placement: WorktreeFilePlacement, failures: [Item], skipped: [String] = []) {
    self.placement = placement
    self.failures = failures
    self.skipped = skipped
  }

  public var description: String {
    failures.map { "\($0.path): \($0.underlying.localizedDescription)" }.joined(separator: "\n")
  }

  /// With another list's entries that named somewhere else, so one message
  /// says both: a second would take the one alert or pane from the first.
  public func including(skipped entries: [String]) -> WorktreeFileFailure {
    WorktreeFileFailure(placement: placement, failures: failures, skipped: skipped + entries)
  }
}
