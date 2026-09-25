import SwiftUI

/// A drop on a group's strip clear of its tabs: the tab lands last there.
/// Registered under the tabs, so a miss still means something.
struct TabStripDropDelegate: DropDelegate {
  let drop: () -> Bool

  func validateDrop(info: DropInfo) -> Bool { info.carriesATab }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool { drop() }
}
