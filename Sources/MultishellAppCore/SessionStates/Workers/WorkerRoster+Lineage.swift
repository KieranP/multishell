import MultishellCore

/// Who launched whom, through the parents still on the roster.
extension WorkerRoster {
  /// Every worker above one of the ids.
  func ancestors(of ids: Set<String>) -> Set<String> {
    let parents = Dictionary(keepingFirst: workers.map { ($0.id, $0.parentID) })
    var found: Set<String> = []
    for id in ids {
      var next = parents[id] ?? nil
      while let parentID = next, parents[parentID] != nil, found.insert(parentID).inserted {
        next = parents[parentID] ?? nil
      }
    }
    return found
  }

  /// The ids and every worker under one of them. Claude's Stop lists only
  /// background work, so a foreground worker is out while its parent is.
  func withDescendants(of ids: Set<String>) -> Set<String> {
    var found = ids
    var isGrowing = true
    while isGrowing {
      isGrowing = false
      for worker in workers where !found.contains(worker.id) {
        guard let parentID = worker.parentID, found.contains(parentID) else { continue }
        found.insert(worker.id)
        isGrowing = true
      }
    }
    return found
  }
}
