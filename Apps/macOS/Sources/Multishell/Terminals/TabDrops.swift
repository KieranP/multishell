import MultishellAppCore
import MultishellCore
import SwiftUI

// The four places a dragged tab can land: on a tab, on the strip past its
// tabs, on a column's terminal area, and on the band down one of its edges.
// One file rather than four, as `*Failures.swift` groups the errors that go
// together: each is a few lines of the same shape, and each answers the drag
// before it moves the tab, for the reason below.

/// Runs the move a drop asked for on the next turn of the main actor, one
/// frame later, which reads as instant.
///
/// Every drop here clears the highlight and returns `true` at once, then
/// comes through this: the drag ends against the view tree it began in
/// rather than one the move has already changed under it. `true` even where
/// the move turns out to do nothing, since a refused drop is what makes
/// AppKit slide its preview all the way home, and a drop this app has taken
/// should not look like a failure.
private func afterTheDrag(_ move: @escaping @MainActor () -> Void) {
  Task { @MainActor in move() }
}

/// Tracks the pointer over a tab so the strip can draw the insertion line,
/// and performs the move on release. The dragged id lives in the worktree's
/// drag state, set when the drag starts, so no item provider has to be
/// decoded asynchronously here.
///
/// The sidebar's `ProjectDropDelegate` is this same shape stood upright:
/// there the halves are top and bottom, here they are leading and trailing.
struct TabDropDelegate: DropDelegate {
  let tabID: TerminalTab.ID
  let width: CGFloat
  @Binding var drag: TabDragState
  let perform: (TerminalTab.ID, TerminalTab.Placement) -> Void
  /// Called as the pointer passes this tab, to move the dragged tab past it
  /// there and then; see `AppModel.shuffleTab`. It answers for itself
  /// whether the move belongs to this moment or to the drop.
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

  /// A tab is a target and a band is a target, and the pointer crossing
  /// from one to the other can leave the band's own exit unreported, which
  /// would light both. The tab is the more specific of the two, so it wins.
  private func enter(_ info: DropInfo) {
    drag.insertion = TabDragState.Insertion(tabID: tabID, placement: placement(for: info))
    drag.band = nil
  }

  /// Which half the pointer is in. A width not yet measured reads as the
  /// leading half, which is where a strip that has not laid out yet would
  /// want it anyway.
  private func placement(for info: DropInfo) -> TerminalTab.Placement {
    width > 0 && info.location.x >= width / 2 ? .after : .before
  }
}

/// A drop on a column's strip clear of its tabs, its New Tab button
/// included: the tab lands last in that column. Registered on the strip
/// itself, under the tabs, so a drop that misses every tab still means
/// something rather than merely ending the drag.
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

/// A column's whole terminal area, under the bands down its edges.
///
/// Two jobs. It is what says the pointer has arrived over this column, which
/// is what the bands are drawn from, and what says it has left, so they go.
/// And a drop between the bands moves the tab into this column, last in its
/// strip, the same as a drop on the strip's own empty space.
///
/// It could have taken the drop and done nothing, the edges being the
/// interesting targets, but a target has to be here either way: a release
/// that reaches no target of ours is what leaves a highlight on screen with
/// no drag behind it. Given that, joining the column is the honest answer to
/// a move cursor, and the least surprising thing to happen when a tab is let
/// go over a terminal.
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

  /// A tab is the more specific target, so arriving here gives up any line
  /// a strip was drawing: the pointer crossing from one to the other can
  /// leave the other's exit unreported.
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
