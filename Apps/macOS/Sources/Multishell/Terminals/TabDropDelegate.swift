import MultishellCore
import SwiftUI

struct TabDropTarget: Equatable {
  let tabID: TerminalTab.ID
  let placement: TerminalTab.Placement
}

/// Tracks the pointer over a tab so the strip can draw the insertion line,
/// and performs the move on release. The dragged id lives in the strip's
/// state, set when the drag starts, so no item provider has to be decoded
/// asynchronously here.
///
/// The sidebar's `ProjectDropDelegate` is this same shape stood upright:
/// there the halves are top and bottom, here they are leading and trailing.
struct TabDropDelegate: DropDelegate {
  let tabID: TerminalTab.ID
  let width: CGFloat
  @Binding var target: TabDropTarget?
  let perform: (TerminalTab.Placement) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [TabTransfer.contentType])
  }

  func dropEntered(info: DropInfo) {
    target = TabDropTarget(tabID: tabID, placement: placement(for: info))
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    target = TabDropTarget(tabID: tabID, placement: placement(for: info))
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if target?.tabID == tabID { target = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let placement = placement(for: info)
    target = nil
    perform(placement)
    Task { @MainActor [$target] in $target.wrappedValue = nil }
    return true
  }

  /// Which half the pointer is in. A width not yet measured reads as the
  /// leading half, which is where a strip that has not laid out yet would
  /// want it anyway.
  private func placement(for info: DropInfo) -> TerminalTab.Placement {
    width > 0 && info.location.x >= width / 2 ? .after : .before
  }
}
