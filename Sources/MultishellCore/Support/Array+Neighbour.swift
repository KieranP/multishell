extension Array where Element: Identifiable {
  /// The element one place along from `id`, wrapping at either end; `nil`
  /// where it is absent or alone.
  public func neighbour(of id: Element.ID, _ direction: CycleDirection) -> Element? {
    neighbour(direction) { $0.id == id }
  }
}

extension Array where Element: Equatable {
  /// The value one place along from `value`, wrapping as an identified one does.
  public func neighbour(ofValue value: Element, _ direction: CycleDirection) -> Element? {
    neighbour(direction) { $0 == value }
  }
}

extension Array {
  /// Backwards is `count - 1` forwards, for `%`.
  private func neighbour(_ direction: CycleDirection, of isCurrent: (Element) -> Bool) -> Element? {
    guard count > 1, let index = firstIndex(where: isCurrent) else { return nil }
    let step = direction == .next ? 1 : count - 1
    return self[(index + step) % count]
  }
}
