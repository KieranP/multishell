import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectDropTarget: Equatable {
  let projectID: Project.ID
  let edge: VerticalEdge
}

/// Tracks the pointer over a project block for the insertion line, and moves
/// on release. The dragged id lives in the sidebar's state.
struct ProjectDropDelegate: DropDelegate {
  let projectID: Project.ID
  let blockHeight: CGFloat
  @Binding var target: ProjectDropTarget?
  /// Takes the id out of the drop rather than out of the sidebar's state:
  /// `.onDrag` has no cancellation callback, so a drag abandoned outside the
  /// scroll view leaves that state set and the next text drop would move it.
  let perform: (Project.ID?, VerticalEdge) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [.text])
  }

  func dropEntered(info: DropInfo) {
    target = ProjectDropTarget(projectID: projectID, edge: edge(for: info))
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    target = ProjectDropTarget(projectID: projectID, edge: edge(for: info))
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if target?.projectID == projectID { target = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let edge = edge(for: info)
    target = nil
    Task { @MainActor [$target] in $target.wrappedValue = nil }
    guard let provider = info.itemProviders(for: [.text]).first else {
      perform(nil, edge)
      return false
    }
    // Always answered, whatever the payload turns out to be: the sidebar's
    // drag state is cleared here and nothing else clears it on this path.
    _ = provider.loadObject(ofClass: NSString.self) { dragged, _ in
      // To `String` before the hop: `NSString` is not `Sendable`.
      let id = dragged as? String
      Task { @MainActor in perform(id, edge) }
    }
    return true
  }

  private func edge(for info: DropInfo) -> VerticalEdge {
    info.location.y < blockHeight / 2 ? .top : .bottom
  }
}
