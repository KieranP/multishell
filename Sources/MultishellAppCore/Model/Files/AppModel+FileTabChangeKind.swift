import MultishellCore
import MultishellGitKit

extension AppModel {
  /// What happened to a tab's file, for its corner dot: from the diff it drew
  /// or kept when hidden, else the status, which knows a binary file's change.
  public func changeKind(of tab: FileTab) -> StatusChange.Kind? {
    guard let reading = fileTabReadings[tab.id] else { return nil }
    if reading.isFileGone { return .deleted }
    if case .released(let kind) = reading.content { return kind }
    let statusKind = statusChangeKind(of: tab)
    if case .releasedFollowingStatus = reading.content { return statusKind }
    // An empty file has no rows to tell; every row added may be a file
    // committed empty, which only its status calls modified.
    if case .text(let rows) = reading.content, !rows.lines.isEmpty {
      if rows.lines.contains(where: { $0.kind != .added }) {
        return rows.hasLineChanges || rows.hasModeChange ? .modified : nil
      }
      return statusKind == .modified ? .modified : .added
    }
    return statusKind
  }

  /// Struck through in the strip, the bar and the command line.
  public func isFileGone(of id: FileTab.ID) -> Bool {
    fileTabReadings[id]?.isFileGone == true
  }

  /// The status's kind for the tab's file; a submodule's status lists its
  /// files, where the worktree's names the submodule alone.
  private func statusChangeKind(of tab: FileTab) -> StatusChange.Kind? {
    // The innermost still read: one inside another lists its files apart, and
    // one collapsed or under a shut panel is no longer read again.
    let isRead = showsFilesPanel && filesPanelWorktree?.id == tab.worktreeID
    let read = isRead ? expandedSubmodules(of: tab.worktreeID) : [:]
    let submodule = read.filter { path, _ in tab.path.hasPrefix(path + "/") }
      .max { $0.key.count < $1.key.count }
    guard let (folder, reading) = submodule else { return worktreeChangeKind(of: tab) }
    let inside = String(tab.path.dropFirst(folder.count + 1))
    return reading.status?.kind(of: inside)
  }

  /// Under Branch the panel's current read, counting from the merge base as the
  /// tab does, or none where it holds none (files.md); else the status's.
  private func worktreeChangeKind(of tab: FileTab) -> StatusChange.Kind? {
    if case .branch(let changes) = changeComparison(of: tab.worktreeID) {
      // No shared history leaves the tab counting from `HEAD`, as the status does.
      guard changes.mergeBase == nil else { return changes.kind(of: tab.path) }
    } else if fileTabBase(in: tab.worktreeID) != nil {
      return nil
    }
    return statuses[tab.worktreeID]?.kind(of: tab.path)
  }
}
