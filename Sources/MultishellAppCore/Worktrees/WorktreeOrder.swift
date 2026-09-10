import Foundation
import MultishellCore

/// The order a project's worktree rows are drawn in.
///
/// The main worktree, and the one sitting on the project's trunk, keep the
/// top whatever the sort says: they are the rows every other worktree is
/// read against, and a list that moved them would read as a different
/// project. Pure, so the rules are tested without a sidebar; the runtime
/// state behind "active" is asked of the caller.
public struct WorktreeOrder: Equatable, Sendable {
  /// Taken for the trunk while the project has resolved no default branch:
  /// nothing has told us which branch it is, and these two are the guess
  /// git itself makes.
  public static let fallbackTrunkNames = ["main", "master"]

  public let order: WorktreeSortOrder
  public let activeFirst: Bool
  /// The project's trunk, as `DefaultBranch.branch` gives it and without
  /// the remote in front of it, or `nil` while none is resolved.
  public let trunkBranch: String?

  public init(order: WorktreeSortOrder, activeFirst: Bool, trunkBranch: String? = nil) {
    self.order = order
    self.activeFirst = activeFirst
    self.trunkBranch = trunkBranch
  }

  /// Which band a worktree is listed in, before the sort orders each band.
  private enum Band: Int {
    /// git's own main worktree, which is the repository in a bare layout.
    case primary
    /// A linked worktree checked out on the trunk, which is where the trunk
    /// lives when the repository itself is bare.
    case trunk
    case active
    case other
  }

  /// `displayName` is what the row shows, `isActive` whether anything is
  /// going on in the worktree, and `lastCommit` when its branch was last
  /// committed to. Each is asked once per worktree: they read runtime state,
  /// which the caller holds.
  public func sort(
    _ worktrees: [Worktree],
    displayName: (Worktree) -> String,
    isActive: (Worktree) -> Bool,
    lastCommit: (Worktree) -> Date?
  ) -> [Worktree] {
    worktrees
      .map { worktree in
        Key(
          band: band(of: worktree, isActive: isActive(worktree)),
          name: displayName(worktree),
          createdAt: worktree.createdAt,
          lastCommit: lastCommit(worktree),
          worktree: worktree)
      }
      .sorted(by: precedes)
      .map(\.worktree)
  }

  private struct Key {
    let band: Band
    let name: String
    let createdAt: Date?
    let lastCommit: Date?
    let worktree: Worktree
  }

  private func band(of worktree: Worktree, isActive: Bool) -> Band {
    if worktree.isPrimary { return .primary }
    if let branch = worktree.branch, isTrunk(branch) { return .trunk }
    return activeFirst && isActive ? .active : .other
  }

  private func isTrunk(_ branch: String) -> Bool {
    guard let trunkBranch else { return Self.fallbackTrunkNames.contains(branch) }
    return branch == trunkBranch
  }

  /// Total and stable: every comparison falls through to the path, so two
  /// worktrees dated the same second do not swap places between renders.
  private func precedes(_ a: Key, _ b: Key) -> Bool {
    if a.band != b.band { return a.band.rawValue < b.band.rawValue }
    switch order {
    case .alphabetical:
      break
    case .createdNewestFirst, .createdOldestFirst:
      if let byDate = Self.compare(
        a.createdAt, b.createdAt, newestFirst: order == .createdNewestFirst)
      {
        return byDate
      }
    case .committedNewestFirst, .committedOldestFirst:
      if let byDate = Self.compare(
        a.lastCommit, b.lastCommit, newestFirst: order == .committedNewestFirst)
      {
        return byDate
      }
    }
    let byName = a.name.localizedStandardCompare(b.name)
    if byName != .orderedSame { return byName == .orderedAscending }
    return a.worktree.id < b.worktree.id
  }

  /// `nil` where the dates cannot separate the two, so the name decides.
  ///
  /// A date nobody knows sorts after every date we have, in both
  /// directions: "oldest first" is not a claim that an undated worktree is
  /// the oldest, and neither is "recently committed last" about a branch that
  /// carried no date at all.
  private static func compare(_ a: Date?, _ b: Date?, newestFirst: Bool) -> Bool? {
    if (a == nil) != (b == nil) { return b == nil }
    guard let a, let b, a != b else { return nil }
    return newestFirst ? a > b : a < b
  }
}
