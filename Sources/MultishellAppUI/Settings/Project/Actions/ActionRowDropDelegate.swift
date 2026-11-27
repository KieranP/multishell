import MultishellAppCore
import SwiftUI

/// One of the user's rows on the Actions page as a drop target: the half the
/// pointer is in says whether the dragged row goes before or after it.
struct ActionRowDropDelegate: DropDelegate {
  let row: Int
  let height: Double
  @Binding var drop: ActionRowDrop?
  let perform: (ActionRowDrop) -> Bool

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [ActionRowTransfer.contentType])
  }

  func dropEntered(info: DropInfo) {
    drop = target(of: info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    drop = target(of: info)
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if drop?.row == row { drop = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    drop = nil
    return perform(target(of: info))
  }

  private func target(of info: DropInfo) -> ActionRowDrop {
    ActionRowDrop(row: row, isAfter: DropHalf(at: info.location.y, along: height) == .trailing)
  }
}
