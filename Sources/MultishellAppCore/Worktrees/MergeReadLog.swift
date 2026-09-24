import Foundation
import MultishellCore

/// When and at what cost each worktree's merge verdict was last read, and how
/// much re-asking one round may start across its projects; see merged-branch.md.
struct MergeReadLog: Sendable {
  /// A round starts re-asks until their last costs add up to this, and always
  /// one a project, so a fetch that moved every branch's base does not start them all.
  var budget: Duration = .seconds(2)
  /// What a branch never read is taken to cost against the round.
  var unmeasured: Duration = .milliseconds(250)

  private var reads = ReadCosts()
  private var spent = Duration.zero

  /// The poll's round asks every project; each project's re-asks draw on what
  /// the ones before left, and a lone refresh meanwhile leaves it alone.
  mutating func beginRound() {
    spent = .zero
  }

  /// The worktrees whose reads fit: every one never read, having no badge to
  /// wait behind, then the longest since answered. Alone, a budget of its own.
  mutating func admit(_ ids: [Worktree.ID], sharingRound: Bool) -> Set<Worktree.ID> {
    var used = sharingRound ? spent : .zero
    let unread = ids.filter { reads[$0] == nil }
    var admitted = Set(unread)
    used += unmeasured * unread.count
    let answered = ids.enumerated().compactMap { offset, id in
      reads[id].map { (id: id, offset: offset, at: $0.at, took: $0.took) }
    }
    for read in answered.sorted(by: { ($0.at, $0.offset) < ($1.at, $1.offset) }) {
      if !admitted.isEmpty, used + read.took > budget { break }
      admitted.insert(read.id)
      used += read.took
    }
    if sharingRound { spent = used }
    return admitted
  }

  mutating func remember(_ costs: [Worktree.ID: Duration]) {
    reads.remember(costs)
  }

  mutating func forget(_ gone: some Sequence<Worktree.ID>) {
    reads.forget(gone)
  }
}
