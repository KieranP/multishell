import Foundation
import MultishellCore

/// Whether a tab dragged along its own strip should move now. Index arithmetic
/// matching `WorkspaceStore.moveTab`, a disagreement never settling.
public enum TabShuffle {
  /// Whether that move changes the order of `order`, one column's tabs as
  /// drawn. `false` over its own tab, which is how a shuffle oscillates.
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
