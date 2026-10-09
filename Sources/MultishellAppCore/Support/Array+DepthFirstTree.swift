extension Array {
  /// Each element after its parent, depth first, with its depth. An orphan starts a
  /// tree, then whatever a loop of parents left does, in `leftoverOrder`.
  func depthFirstTree<ID: Hashable>(
    id: (Element) -> ID, parentID: (Element) -> ID?,
    siblingOrder: ([Element]) -> [Element] = { $0 },
    leftoverOrder: ([Element]) -> [Element] = { $0 }
  ) -> [(element: Element, depth: Int)] {
    let ids = Set(map(id))
    let parented = compactMap { element in
      parentID(element).flatMap { ids.contains($0) ? ($0, element) : nil }
    }
    let childrenByParent = Dictionary(grouping: parented, by: \.0).mapValues { $0.map(\.1) }
    var placed: Set<ID> = []
    var ordered: [(element: Element, depth: Int)] = []
    func place(_ element: Element, depth: Int) {
      guard placed.insert(id(element)).inserted else { return }
      ordered.append((element, depth))
      for child in siblingOrder(childrenByParent[id(element)] ?? []) {
        place(child, depth: depth + 1)
      }
    }
    for root in siblingOrder(filter { parentID($0).map(ids.contains) != true }) {
      place(root, depth: 0)
    }
    for leftover in leftoverOrder(self) { place(leftover, depth: 0) }
    return ordered
  }
}
