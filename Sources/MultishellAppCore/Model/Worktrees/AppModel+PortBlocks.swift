import Foundation
import MultishellCore

extension AppModel {
  /// What Settings > Worktrees says under the port fields while a worktree has
  /// no port, each named with its project; `nil` once every one has a port.
  public var worktreesWithoutPortsCaption: String? {
    let without = workspace.worktreesWithoutPorts
    guard !without.isEmpty else { return nil }
    let names = without.map { worktree in
      let name = workspace.displayName(of: worktree)
      guard let project = workspace.project(worktree.projectID) else { return name }
      return t("port-block.worktree", name, project.name)
    }
    return t(
      "port-block.caption",
      ListFormatter.localizedString(byJoining: names),
      PortBlock.highestPort,
    )
  }

  /// A worktree just created with no block. Never over another alert, the
  /// caption keeping the record; see Docs/design/worktrees.md.
  func alertNoPortBlock(for worktree: Worktree) {
    guard presentedError == nil else { return }
    // Owned by no request, so a command line create that caused it still succeeds.
    presentedError = ControlRequestScope.$id.withValue(nil) {
      .noPortBlock(workspace.displayName(of: worktree))
    }
  }
}
