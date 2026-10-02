extension Sequence where Element: Identifiable {
  /// Each element by its id, the first kept where two share one.
  public func keyedByID() -> [Element.ID: Element] {
    Dictionary(map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }
}
