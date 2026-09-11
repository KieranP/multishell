extension TerminalTab {
  /// Where a dragged tab lands relative to the tab it was dropped on. Nested
  /// because SwiftUI has a `TabPlacement` a view would have to disambiguate.
  public enum Placement: Equatable, Sendable {
    case before
    case after
  }
}
