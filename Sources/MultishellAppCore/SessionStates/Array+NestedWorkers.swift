extension [Worker] {
  /// Each worker after its parent, siblings in the order they started. One
  /// whose parent is not out is drawn at the top.
  public var nested: [NestedWorker] {
    let ids = Set(map(\.id))
    let childrenByParent = Dictionary(grouping: filter { $0.parentID.map(ids.contains) == true }) {
      $0.parentID ?? ""
    }
    var placed: Set<String> = []
    var ordered: [NestedWorker] = []
    func place(_ worker: Worker, depth: Int) {
      guard placed.insert(worker.id).inserted else { return }
      ordered.append(NestedWorker(worker: worker, depth: depth))
      for child in childrenByParent[worker.id] ?? [] { place(child, depth: depth + 1) }
    }
    for worker in self where worker.parentID.map(ids.contains) != true {
      place(worker, depth: 0)
    }
    // Workers naming each other have no top, so what a loop left is drawn there.
    for worker in self { place(worker, depth: 0) }
    return ordered
  }
}
