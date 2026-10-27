/// Where the quick switcher's list scrolls as its selection moves.
public enum QuickSwitcherScrollTarget: Equatable, Sendable {
  case row(QuickSwitcherTarget)
  /// A section's title, with the first row under it.
  case sectionTitle(QuickSwitcherSection.Kind)
  /// The top of the list, its first title in view.
  case top
}
