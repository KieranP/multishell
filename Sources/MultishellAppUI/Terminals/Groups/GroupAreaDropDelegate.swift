import MultishellAppCore
import MultishellCore
import SwiftUI

/// A group's terminal area, under the bands: it says when the pointer
/// arrives and leaves, and a drop between them joins this group.
struct GroupAreaDropDelegate: DropDelegate {
  let groupID: TabGroup.ID
  @Binding var drag: TabDragState
  let drop: () -> Bool

  func validateDrop(info: DropInfo) -> Bool { info.carriesATab }

  func dropEntered(info: DropInfo) {
    track()
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    track()
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.overGroup == groupID { drag.overGroup = nil }
  }

  func performDrop(info: DropInfo) -> Bool { drop() }

  /// Arriving here gives up any line a strip was drawing, the pointer
  /// crossing between targets leaving an exit unreported.
  private func track() {
    drag.overGroup = groupID
    drag.insertion = nil
  }
}
