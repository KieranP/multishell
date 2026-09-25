import MultishellAppCore
import MultishellCore
import SwiftUI
import UniformTypeIdentifiers

/// Tracks the pointer over a project block for the insertion line, and moves
/// on release.
struct ProjectBlockDropDelegate: DropDelegate {
  let projectID: Project.ID
  let blockHeight: CGFloat
  @Binding var target: ProjectDropTarget?
  /// From the drop, not the sidebar's state: the payload can load after the drag
  /// session has ended, and that end clears it.
  let drop: (Project.ID?, ProjectPlacement) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [.text])
  }

  func dropEntered(info: DropInfo) {
    track(info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    track(info)
    return DropProposal(operation: .move)
  }

  /// Written only on a change: an update arrives at pointer rate, and each
  /// write to the sidebar's state may rebuild the whole of it.
  private func track(_ info: DropInfo) {
    let next = ProjectDropTarget(projectID: projectID, placement: placement(for: info))
    if target != next { target = next }
  }

  func dropExited(info: DropInfo) {
    if target?.projectID == projectID { target = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let placement = placement(for: info)
    target = nil
    Task { @MainActor [$target] in $target.wrappedValue = nil }
    guard let provider = info.itemProviders(for: [.text]).first else {
      drop(nil, placement)
      return false
    }
    _ = provider.loadObject(ofClass: NSString.self) { dragged, _ in
      // To `String` before the hop: `NSString` is not `Sendable`.
      let id = dragged as? String
      Task { @MainActor in drop(id, placement) }
    }
    return true
  }

  private func placement(for info: DropInfo) -> ProjectPlacement {
    DropHalf(at: info.location.y, along: blockHeight) == .leading ? .above : .below
  }
}
