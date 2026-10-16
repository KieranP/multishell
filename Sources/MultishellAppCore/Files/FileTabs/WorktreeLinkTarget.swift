import Foundation
import MultishellCore

/// Where a path in a worktree leads once its link is followed: git diffs a
/// link as the path it holds, so a tab shows the file it points at instead.
enum WorktreeLinkTarget {
  /// `nil` where the link leads out of the worktree or to nothing; a path that
  /// is no link is itself.
  static func path(of path: String, in worktree: URL) -> String? {
    let url = worktree.appending(path: path)
    let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
    guard values?.isSymbolicLink == true else { return path }
    let resolved = url.resolvingSymlinksInPath()
    // Foundation hands back a link to nothing unresolved.
    let resolvedValues = try? resolved.resourceValues(forKeys: [.isSymbolicLinkKey])
    guard resolvedValues?.isSymbolicLink == false else { return nil }
    let roots = [worktree.resolvingSymlinksInPath(), worktree]
    guard let components = roots.lazy.compactMap({ resolved.pathComponents(under: $0) }).first,
      !components.isEmpty
    else { return nil }
    return components.joined(separator: "/")
  }
}
