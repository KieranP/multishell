import MultishellCore

/// The memory of workers taken off, so a child whose parent is named only
/// after that parent ended is still drawn under it.
extension WorkerRoster {
  /// Far more parents than a fan-out names; the oldest is forgotten past it.
  private static let retiredLimit = 64

  mutating func remember(_ worker: Worker) {
    guard worker.pid == nil, worker.id != Worker.overflowID else { return }
    retired.removeAll { $0.id == worker.id }
    retired.append(worker)
    if retired.count > Self.retiredLimit { retired.removeFirst() }
  }

  /// A parent named after it retired goes back on above its child, stopped, and
  /// so does its own, so the child is drawn where it belongs.
  mutating func bringBackRetiredParents(of id: String) {
    var childID = id
    while let childIndex = workers.firstIndex(where: { $0.id == childID }),
      let parentID = workers[childIndex].parentID, !isOut(parentID),
      workers.count < SessionStateReport.rosterCapacity,
      let retiredIndex = retired.lastIndex(where: { $0.id == parentID })
    {
      var parent = retired.remove(at: retiredIndex)
      parent.hasEnded = true
      parent.occurrences = 1
      workers.insert(parent, at: childIndex)
      childID = parentID
    }
  }
}
