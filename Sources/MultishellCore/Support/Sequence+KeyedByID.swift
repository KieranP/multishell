extension Sequence where Element: Identifiable {
  /// Each element by its id, the first kept where two share one.
  public func keyedByID() -> [Element.ID: Element] {
    Dictionary(keepingFirst: map { ($0.id, $0) })
  }
}
