import Foundation

/// Cancel Auto-Merge in flight for one worktree: off from the click until the
/// list shows auto-merge off, or answers from a read begun after `gh` returned.
struct AutoMergeCancellation: Equatable, Sendable {
  /// One per click, so a `gh` call whose cancel was dropped leaves a later one be.
  let attempt = UUID()
  /// The page of the pull request it cancels, which a checkout may stop showing.
  let pullRequestURL: URL
  /// `nil` while `gh` runs.
  var acceptedAt: ContinuousClock.Instant?
}
