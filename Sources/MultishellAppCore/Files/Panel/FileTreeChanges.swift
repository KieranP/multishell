import Foundation

/// The changed paths' half of a `FileTree`, kept while only counts move:
/// 50,000 new files took 0.3 s to build on the main actor for each status read.
struct FileTreeChanges: Sendable {
  private let paths: Set<String>
  private let repositories: Set<String>
  let sortedPaths: [String]
  /// `sortedPaths` folded once, so a filter folds only its own text.
  let foldedPaths: [String]
  let roots: [FileTree.Node]
  /// Every folder above a change, which shows a dot while it is shut.
  let foldersHoldingChanges: Set<String>

  init(_ paths: Set<String>, repositories: Set<String>) {
    self.paths = paths
    self.repositories = repositories
    sortedPaths = paths.sorted()
    foldedPaths = sortedPaths.map(\.foldedForMatching)
    var holding: Set<String> = []
    for path in paths {
      var parts = path.split(separator: "/").dropLast()
      while !parts.isEmpty {
        holding.insert(parts.joined(separator: "/"))
        parts = parts.dropLast()
      }
    }
    foldersHoldingChanges = holding
    roots = FileTree.build(
      Array(paths),
      folders: repositories,
      repositories: repositories,
      ignored: [],
    )
  }

  func isBuilt(from paths: Set<String>, repositories: Set<String>) -> Bool {
    self.paths == paths && self.repositories == repositories
  }
}
