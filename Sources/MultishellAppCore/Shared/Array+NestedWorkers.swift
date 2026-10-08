extension [Worker] {
  /// Each worker after its parent, siblings in the order they started. One
  /// whose parent is not out, or that names a parent in a loop, is drawn at the top.
  public var nested: [NestedWorker] {
    depthFirstTree(id: \.id, parentID: \.parentID).map {
      NestedWorker(worker: $0.element, depth: $0.depth)
    }
  }
}
