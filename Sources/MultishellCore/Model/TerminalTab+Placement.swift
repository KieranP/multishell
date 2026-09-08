extension TerminalTab {
  /// Where a dragged tab lands relative to the tab it was dropped on.
  ///
  /// Unlike `ProjectPlacement`, which the model turns into an index before
  /// the store sees it, this reaches the store: landing after the last tab
  /// names no tab to be "before". Nested, because SwiftUI has a
  /// `TabPlacement` of its own that a view would otherwise have to
  /// disambiguate.
  public enum Placement: Equatable, Sendable {
    case before
    case after
  }
}
