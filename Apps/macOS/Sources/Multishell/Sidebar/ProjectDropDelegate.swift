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
  let perform: (VerticalEdge) -> Void

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
    perform(edge)
    Task { @MainActor [$target] in $target.wrappedValue = nil }
    return true
  }

  private func edge(for info: DropInfo) -> VerticalEdge {
    info.location.y < blockHeight / 2 ? .top : .bottom
  }
}
