import Foundation
import MultishellCore

/// Whether a tab being dragged along its own strip should move now.
///
/// Tab strips move their tabs out of the way as the pointer passes them,
/// rather than leaving everything to jump when it is let go, and this is the
/// question that asks: given where the pointer is, would the strip read
/// differently? Kept apart from the view because it is index arithmetic that
/// has to match `WorkspaceStore.moveTab` exactly — a disagreement between
/// the two is a tab that moves on every mouse event and never settles.
public enum TabShuffle {
  /// Whether moving `moving` to `placement` of `anchor` changes the order of
  /// `order`, which is one column's tabs as the strip draws them.
  ///
  /// `false` where the drag is over its own tab, which is where the pointer
  /// ends up after each move: the tab that just slid under the pointer is
  /// not an anchor to move it past, and reading it as one is how a shuffle
  /// starts oscillating.
  public static func reorders(
    _ moving: TerminalTab.ID,
    _ placement: TerminalTab.Placement,
    of anchor: TerminalTab.ID,
    in order: [TerminalTab.ID]
  ) -> Bool {
    guard moving != anchor else { return false }
    guard let from = order.firstIndex(of: moving), let to = order.firstIndex(of: anchor) else {
      return false
    }
    var shuffled = order
    shuffled.remove(at: from)
    // Taking the tab out shifts the anchor down by one where it sat after
    // it; `WorkspaceStore.moveTab` does the same sum on the flat array.
    let slot = to > from ? to - 1 : to
    shuffled.insert(moving, at: placement == .before ? slot : slot + 1)
    return shuffled != order
  }
}
