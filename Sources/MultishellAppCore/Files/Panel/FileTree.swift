import Foundation
import MultishellCore
import MultishellGitKit

/// Every file of a worktree as a tree: its listing, kept while only counts
/// move, and the changes marked on it; flattened per panel state. See files.md.
struct FileTree: Sendable {
  struct Node: Sendable {
    let name: String
    let path: String
    let children: [Self]
    let isFolder: Bool
    let isRepository: Bool
    let isIgnored: Bool
  }

  let listing: FileTreeListing
  let changes: FileTreeChanges
  private let changeKinds: [String: StatusChange.Kind]
  private let lineCounts: [String: FileLineCounts]

  /// The number the Changes list shows: each changed path once, a file both removed
  /// from the index and left on disk being one row; counted while `changes` builds.
  let changedFileCount: Int

  /// An opened submodule's files count in no Changes list of the worktree's, and
  /// what git ignores lists greyed, in Files alone; see Docs/design/files.md.
  init(
    _ sources: FileTreeSources,
    listing: FileTreeListing,
    changes: FileTreeChanges,
  ) {
    self.listing = listing
    self.changes = changes
    var kinds: [String: StatusChange.Kind] = [:]
    var counts: [String: FileLineCounts] = [:]
    func add(_ change: StatusChange) {
      kinds[change.path] = kinds[change.path]?.combined(with: change.kind) ?? change.kind
      guard let changeCounts = FileLineCounts(change.lines) else { return }
      let total = counts[change.path]
      counts[change.path] = FileLineCounts(
        insertions: (total?.insertions ?? 0) + changeCounts.insertions,
        deletions: (total?.deletions ?? 0) + changeCounts.deletions,
      )
    }
    sources.markedChanges.forEach(add)
    // A submodule's paths sit under its folder, so none is one of the worktree's.
    changedFileCount = kinds.count
    // Its changes are against its own `HEAD`, which Branch does not count from.
    if sources.branchChanges == nil { Self.submoduleChanges(in: sources).forEach(add) }
    changeKinds = kinds
    lineCounts = counts
  }

  /// The worktree's changes and an opened submodule's, under its folder.
  static func statusChanges(in sources: FileTreeSources) -> [StatusChange] {
    (sources.status?.changes ?? []) + submoduleChanges(in: sources)
  }

  private static func submoduleChanges(in sources: FileTreeSources) -> [StatusChange] {
    sources.submodules.flatMap { folder, submodule in
      (submodule.status?.changes ?? []).map { $0.prefixed(byFolder: folder) }
    }
  }

  /// git's output decodes a byte that is not UTF-8 as U+FFFD, so such a name
  /// no longer matches the file's.
  static func isOpenable(_ path: String, notCheckedOut: Set<String>) -> Bool {
    !notCheckedOut.contains(path) && !path.unicodeScalars.contains("\u{FFFD}")
  }

  func isOpenable(_ path: String) -> Bool {
    Self.isOpenable(path, notCheckedOut: listing.notCheckedOutFiles)
  }

  /// A filter lists the matching files flat; otherwise the open folders'
  /// contents, the Changes list merging each chain of single-child folders.
  func rows(state: FilesPanelState) -> [FileTreeRow] {
    let isChangesList = state.mode == .changes
    guard state.filterText.isEmpty else {
      let candidates = isChangesList ? changes.sortedPaths : listing.filePaths
      let folded = isChangesList ? changes.foldedPaths : listing.foldedFilePaths
      let filter = state.filterText.foldedForMatching
      // What a shut folder read from disk holds stays out, as when unread.
      let shut = listing.readFolders.subtracting(state.expandedFolders).map { $0 + "/" }
      let matches = zip(candidates, folded).filter { path, foldedPath in
        foldedPath.prefoldedContains(filter) && !shut.contains(where: path.hasPrefix)
      }
      // A split and join per row took 200 ms of a 200,000-match filter.
      return matches.map { path, _ in
        let slash = path.utf8.lastIndex(of: UInt8(ascii: "/"))
        return row(
          path: path,
          name: slash.map { String(path[path.index(after: $0)...]) } ?? path,
          parentFolder: slash.map { String(path[..<$0]) },
          depth: 0,
          isIgnored: listing.ignoredFiles.contains(path),
        )
      }
    }
    var rows: [FileTreeRow] = []
    flatten(isChangesList ? changes.roots : listing.roots, depth: 0, state: state, into: &rows)
    return rows
  }

  private func flatten(
    _ nodes: [Node],
    depth: Int,
    state: FilesPanelState,
    into rows: inout [FileTreeRow],
  ) {
    let isChangesList = state.mode == .changes
    for node in nodes {
      guard node.isFolder else {
        rows.append(
          row(
            path: node.path,
            name: node.name,
            parentFolder: nil,
            depth: depth,
            isIgnored: node.isIgnored,
          )
        )
        continue
      }
      var shown = node
      var name = node.name
      while isChangesList, shown.children.count == 1, let only = shown.children.first,
        only.isFolder,
        !only.isRepository
      {
        shown = only
        name += "/" + only.name
      }
      let isExpanded =
        isChangesList
        ? !state.collapsedChangesFolders.contains(shown.path)
        : state.expandedFolders.contains(shown.path)
      rows.append(
        FileTreeRow(
          path: shown.path,
          name: name,
          parentFolder: nil,
          depth: depth,
          isFolder: true,
          isExpanded: isExpanded,
          holdsChange: changes.foldersHoldingChanges.contains(shown.path),
          changeKind: changeKinds[shown.path],
          lineCounts: lineCounts[shown.path],
          isRepository: shown.isRepository,
          isIgnored: shown.isIgnored,
          isOpenable: true,
        )
      )
      if isExpanded { flatten(shown.children, depth: depth + 1, state: state, into: &rows) }
    }
  }

  private func row(
    path: String,
    name: String,
    parentFolder: String?,
    depth: Int,
    isIgnored: Bool,
  ) -> FileTreeRow {
    FileTreeRow(
      path: path,
      name: name,
      parentFolder: parentFolder,
      depth: depth,
      isFolder: false,
      isExpanded: false,
      holdsChange: false,
      changeKind: changeKinds[path],
      lineCounts: lineCounts[path],
      isRepository: false,
      isIgnored: isIgnored,
      isOpenable: isOpenable(path),
    )
  }
}
