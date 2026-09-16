extension Array where Element: Identifiable {
  /// The element one place along from `id`, wrapping at either end; `nil`
  /// where it is absent or alone. Backwards is `count - 1` forwards, for `%`.
  public func neighbour(of id: Element.ID, _ direction: TerminalTab.Placement) -> Element? {
    guard count > 1, let index = firstIndex(where: { $0.id == id }) else { return nil }
    let step = direction == .after ? 1 : count - 1
    return self[(index + step) % count]
  }
}
