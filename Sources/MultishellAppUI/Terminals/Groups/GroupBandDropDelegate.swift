import MultishellAppCore
import SwiftUI

/// The band down one edge of a group's terminal area: on release the
/// dragged tab gets a group of its own on that side.
struct GroupBandDropDelegate: DropDelegate {
  let band: TabDragState.Band
  @Binding var drag: TabDragState
  let drop: () -> Bool

  func validateDrop(info: DropInfo) -> Bool { info.carriesATab }

  func dropEntered(info: DropInfo) {
    drag.band = band
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    drag.band = band
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drag.band == band { drag.band = nil }
  }

  func performDrop(info: DropInfo) -> Bool { drop() }
}
