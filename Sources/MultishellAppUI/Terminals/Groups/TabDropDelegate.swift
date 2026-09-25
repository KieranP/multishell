import MultishellAppCore
import MultishellCore
import SwiftUI

/// Tracks the pointer over a tab for the insertion line, and moves on release.
/// The sidebar's `ProjectBlockDropDelegate` is this same shape stood upright.
struct TabDropDelegate: DropDelegate {
  let tabID: TerminalTab.ID
  let width: CGFloat
  @Binding var drag: TabDragState
  let drop: (TerminalTab.Placement) -> Bool
  /// Called as the pointer passes this tab, to move the dragged tab past it
  /// there and then; see `AppModel.shuffleTab`.
  let shuffle: (TerminalTab.ID, TerminalTab.Placement) -> Void

  func validateDrop(info: DropInfo) -> Bool { info.carriesATab }

  func dropEntered(info: DropInfo) {
    track(info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    track(info)
    if let moving = drag.tabID { shuffle(moving, placement(for: info)) }
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.insertion?.tabID == tabID { drag.insertion = nil }
  }

  func performDrop(info: DropInfo) -> Bool { drop(placement(for: info)) }

  /// The pointer crossing from a band to a tab can leave the band's exit
  /// unreported, lighting both. The tab is more specific, so it wins.
  private func track(_ info: DropInfo) {
    drag.insertion = TabDragState.Insertion(tabID: tabID, placement: placement(for: info))
    drag.band = nil
  }

  private func placement(for info: DropInfo) -> TerminalTab.Placement {
    DropHalf(at: info.location.x, along: width) == .trailing ? .after : .before
  }
}
