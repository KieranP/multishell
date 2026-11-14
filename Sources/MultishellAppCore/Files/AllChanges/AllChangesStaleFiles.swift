import MultishellCore

/// What each All changes tab's next read must read again, gathered between
/// reads and taken by the read that starts.
struct AllChangesStaleFiles {
  private var staleness: [AllChangesTab.ID: AllChangesStaleness] = [:]

  mutating func mark(_ stale: AllChangesStaleness, in id: AllChangesTab.ID) {
    staleness[id] = (staleness[id] ?? .nothing).adding(stale)
  }

  func pending(_ id: AllChangesTab.ID) -> AllChangesStaleness {
    staleness[id] ?? .nothing
  }

  mutating func take(_ id: AllChangesTab.ID) -> AllChangesStaleness {
    staleness.removeValue(forKey: id) ?? .nothing
  }

  mutating func keep(only ids: Set<AllChangesTab.ID>) {
    staleness = staleness.filter { ids.contains($0.key) }
  }
}
