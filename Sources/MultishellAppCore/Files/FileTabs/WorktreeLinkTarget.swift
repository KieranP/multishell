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
    guard let resolved = url.resolvedAsFarAsItExists()?.pathComponents,
      let root = worktree.resolvedAsFarAsItExists()?.pathComponents,
      // Not `pathComponents(under:)`: standardizing drops `/private` only from a path on disk.
      resolved.count > root.count, resolved.starts(with: root)
    else { return nil }
    return isLink ? resolved.dropFirst(root.count).joined(separator: "/") : path
  }
}
