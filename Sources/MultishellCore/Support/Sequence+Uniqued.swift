extension Sequence {
  /// The first element for each id anywhere in the sequence, in order.
  public func uniqued<ID: Hashable>(by id: (Element) -> ID) -> [Element] {
    var seen: Set<ID> = []
    return filter { seen.insert(id($0)).inserted }
  }
}
