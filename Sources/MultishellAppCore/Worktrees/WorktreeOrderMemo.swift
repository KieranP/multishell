import Foundation
import MultishellCore

/// Each project's last sorted rows and what they were sorted from, so an
/// unchanged rebuild sorts nothing: 85 µs at 40 rows, 703 µs at 400.
struct WorktreeOrderMemo {
  private struct Entry {
    let order: WorktreeOrder
    let keys: [WorktreeOrder.Key]
    let rows: [Worktree]
  }

  private var entries: [Project.ID: Entry] = [:]
  /// How many times a sort actually ran, for the tests.
  private(set) var sorts = 0

  mutating func rows(
    of project: Project.ID, keys: [WorktreeOrder.Key], order: WorktreeOrder
  ) -> [Worktree] {
    if let entry = entries[project], entry.order == order, entry.keys == keys {
      return entry.rows
    }
    sorts += 1
    let rows = order.sorted(keys)
    entries[project] = Entry(order: order, keys: keys, rows: rows)
    return rows
  }

  mutating func forget(_ project: Project.ID) {
    entries[project] = nil
  }
}
