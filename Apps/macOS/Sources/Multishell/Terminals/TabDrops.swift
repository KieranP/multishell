import MultishellAppCore
import MultishellCore
import SwiftUI

// The four places a dragged tab can land. One file rather than four: each is
// a few lines of the same shape, and each answers the drag before it moves.

/// Runs the move a drop asked for on the next turn, so the drag ends against
/// the view tree it began in. `true` even where the move does nothing.
private func afterTheDrag(_ move: @escaping @MainActor () -> Void) {
  Task { @MainActor in move() }
}

/// Tracks the pointer over a tab for the insertion line, and moves on release.
/// The sidebar's `ProjectDropDelegate` is this same shape stood upright.
struct TabDropDelegate: DropDelegate {
  let tabID: TerminalTab.ID
  let width: CGFloat
  @Binding var drag: TabDragState
  let perform: (TerminalTab.ID, TerminalTab.Placement) -> Void
  /// Called as the pointer passes this tab, to move the dragged tab past it
  /// there and then; see `AppModel.shuffleTab`.
  let shuffle: (TerminalTab.ID, TerminalTab.Placement) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [TabTransfer.contentType])
  }

  func dropEntered(info: DropInfo) {
    enter(info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    enter(info)
    if let moving = drag.tabID { shuffle(moving, placement(for: info)) }
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.insertion?.tabID == tabID { drag.insertion = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let placement = placement(for: info)
    let moving = drag.tabID
    drag.end()
    if let moving { afterTheDrag { perform(moving, placement) } }
    return true
  }

  /// The pointer crossing from a band to a tab can leave the band's exit
  /// unreported, lighting both. The tab is more specific, so it wins.
  private func enter(_ info: DropInfo) {
    drag.insertion = TabDragState.Insertion(tabID: tabID, placement: placement(for: info))
    drag.band = nil
  }

  /// Which half the pointer is in. A width not yet measured reads as the
  /// leading half.
  private func placement(for info: DropInfo) -> TerminalTab.Placement {
    width > 0 && info.location.x >= width / 2 ? .after : .before
  }
}

/// A drop on a column's strip clear of its tabs: the tab lands last there.
/// Registered under the tabs, so a miss still means something.
struct TabStripDropDelegate: DropDelegate {
  @Binding var drag: TabDragState
  let perform: (TerminalTab.ID) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [TabTransfer.contentType])
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    let moving = drag.tabID
    drag.end()
    if let moving { afterTheDrag { perform(moving) } }
    return true
  }
}

/// A column's terminal area, under the bands: it says when the pointer
/// arrives and leaves, and a drop between them joins this column.
struct TabAreaDropDelegate: DropDelegate {
  let groupID: TabGroup.ID
  @Binding var drag: TabDragState
  let perform: (TerminalTab.ID) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [TabTransfer.contentType])
  }

  func dropEntered(info: DropInfo) {
    enter()
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    enter()
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.overColumn == groupID { drag.overColumn = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let moving = drag.tabID
    drag.end()
    if let moving { afterTheDrag { perform(moving) } }
    return true
  }

  /// Arriving here gives up any line a strip was drawing, the pointer
  /// crossing between targets leaving an exit unreported.
  private func enter() {
    drag.overColumn = groupID
    drag.insertion = nil
  }
}

/// The band down one edge of a column's terminal area: on release the
/// dragged tab gets a column of its own on that side.
struct TabBandDropDelegate: DropDelegate {
  let target: TabDragState.Band
  @Binding var drag: TabDragState
  let perform: (TerminalTab.ID) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [TabTransfer.contentType])
  }

  func dropEntered(info: DropInfo) {
    drag.band = target
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    drag.band = target
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.band == target { drag.band = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let moving = drag.tabID
    drag.end()
    if let moving { afterTheDrag { perform(moving) } }
    return true
  }
}
