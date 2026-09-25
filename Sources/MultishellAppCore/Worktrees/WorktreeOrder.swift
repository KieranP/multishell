import Foundation
import MultishellCore

/// The order a project's worktree rows are drawn in. The main worktree and
/// the trunk keep the top whatever the sort says; see worktrees.md.
struct WorktreeOrder: Equatable, Sendable {
  /// Taken for the trunk while no default branch is resolved: these two are
  /// the guess git itself makes.
  static let fallbackTrunkNames = ["main", "master"]

  let sortOrder: WorktreeSortOrder
  let activeFirst: Bool
  /// The project's trunk, as `DefaultBranch.branchName` gives it and without
  /// the remote in front of it, or `nil` while none is resolved.
  let trunkBranch: String?

  init(sortOrder: WorktreeSortOrder, activeFirst: Bool, trunkBranch: String? = nil) {
    self.sortOrder = sortOrder
    self.activeFirst = activeFirst
    self.trunkBranch = trunkBranch
  }

  /// Which band a worktree is listed in, before the sort orders each band.
  fileprivate enum Band: Int {
    /// git's own main worktree, which is the repository in a bare layout.
    case primary
    /// A linked worktree checked out on the trunk, which is where the trunk
    /// lives when the repository itself is bare.
    case trunk
    case active
    case other
  }

  /// Everything the sort reads, so two equal lists sort the same. The closures
  /// are asked once per worktree: they read runtime state, which the caller holds.
  func keys(
    _ worktrees: [Worktree],
    displayName: (Worktree) -> String,
    isActive: (Worktree) -> Bool,
    lastCommit: (Worktree) -> Date?
  ) -> [Key] {
    worktrees.map { worktree in
      Key(
        band: band(of: worktree, isActive: isActive(worktree)),
        name: displayName(worktree),
        createdAt: worktree.createdAt,
        lastCommit: lastCommit(worktree),
        worktree: worktree)
    }
  }

  func sorted(_ keys: [Key]) -> [Worktree] {
    keys.sorted(by: precedes).map(\.worktree)
  }

  struct Key: Equatable, Sendable {
    fileprivate let band: Band
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
    switch sortOrder {
    case .alphabetical:
      break
    case .createdNewestFirst, .createdOldestFirst:
      if let byDate = Self.compare(
        a.createdAt, b.createdAt, newestFirst: sortOrder == .createdNewestFirst)
      {
        return byDate
      }
    case .committedNewestFirst, .committedOldestFirst:
      if let byDate = Self.compare(
        a.lastCommit, b.lastCommit, newestFirst: sortOrder == .committedNewestFirst)
      {
        return byDate
      }
    }
    let byName = a.name.localizedStandardCompare(b.name)
    if byName != .orderedSame { return byName == .orderedAscending }
    return a.worktree.id < b.worktree.id
  }

  /// `nil` where the dates cannot separate the two, so the name decides. A
  /// date nobody knows sorts last in both directions.
  private static func compare(_ a: Date?, _ b: Date?, newestFirst: Bool) -> Bool? {
    if (a == nil) != (b == nil) { return b == nil }
    guard let a, let b, a != b else { return nil }
    return newestFirst ? a > b : a < b
  }
}
