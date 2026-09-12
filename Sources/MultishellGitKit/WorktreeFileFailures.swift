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

  public init(placement: WorktreePlacement, items: [Item]) {
    self.placement = placement
    self.items = items
  }

  public var description: String {
    items.map { "\($0.path): \($0.underlying.localizedDescription)" }.joined(separator: "\n")
  }
}

/// Raised when the user stopped a list part way through. What was placed
/// before the stop stays, as a stopped hook's work does. `failures` is what
/// had already gone wrong, which the Cancel does not excuse.
public struct WorktreeFilesStopped: Error {
  public let failures: [WorktreeFileFailure.Item]

  public init(failures: [WorktreeFileFailure.Item] = []) {
    self.failures = failures
  }
}

/// A listed path leading out of the repository or worktree, by `..` or a
/// symlinked folder. `LocalizedError`, to read as a sentence in the alert.
public struct WorktreeFileEscape: LocalizedError {
  public init() {}

  public var errorDescription: String? {
    t("worktree-file.escape")
  }
}
