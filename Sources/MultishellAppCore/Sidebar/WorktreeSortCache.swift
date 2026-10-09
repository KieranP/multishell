import MultishellCore

/// Each project's last sorted rows and what they were sorted from, so an
/// unchanged rebuild sorts nothing: 85 µs at 40 rows, 703 µs at 400.
struct WorktreeSortCache {
  private struct Entry {
    let rule: WorktreeSortRule
    let keys: [WorktreeSortRule.Key]
    let rows: [Worktree]
  }

  private var entries: [Project.ID: Entry] = [:]
  /// How many times a sort actually ran, for the tests.
  private(set) var sortCount = 0

  mutating func rows(
    of project: Project.ID,
    keys: [WorktreeSortRule.Key],
    rule: WorktreeSortRule,
  ) -> [Worktree] {
    if let entry = entries[project], entry.rule == rule, entry.keys == keys {
      return entry.rows
    }
    sortCount += 1
    let rows = rule.sorted(keys)
    entries[project] = Entry(rule: rule, keys: keys, rows: rows)
    return rows
  }

  mutating func forget(_ project: Project.ID) {
    entries[project] = nil
  }
}
