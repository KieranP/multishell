import Foundation
import MultishellCore

/// Where a path in a worktree leads once its links are followed: git diffs a
/// link as the path it holds, so a tab shows the file it points at instead.
enum WorktreeLinkTarget {
  /// `nil` where a link anywhere along the path leads out of the worktree or to
  /// nothing; a path whose last part is no link is itself.
  static func path(of path: String, in worktree: URL) -> String? {
    let url = worktree.appending(path: path)
    let isLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    guard let inside = url.resolvedComponents(strictlyUnder: worktree) else { return nil }
    return isLink ? inside.joined(separator: "/") : path
  }
}
