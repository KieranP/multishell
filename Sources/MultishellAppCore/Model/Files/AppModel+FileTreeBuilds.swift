import Foundation
import MultishellCore
import MultishellGitKit

/// The Files panel's tree, cached and built off the main actor where large;
/// see Docs/design/files/panel.md.
extension AppModel {
  /// A listing or a change set is built in the render below this many paths, where
  /// a background build would only flash an empty panel; 200,000 took 1.2 s.
  private static var builtInPlaceBelow: Int { 20_000 }

  /// Built only where something it is built from moved since the last; the
  /// listing only where paths moved, and the last one shown while it builds.
  func fileTree(of id: Worktree.ID) -> FileTree {
    let sources = FileTreeSources(
      tracked: trackedFiles[id] ?? .empty,
      status: statuses[id],
      submodules: submoduleReadings[id] ?? [:],
      ignoredEntries: ignoredEntries[id] ?? [],
      ignoredFolderEntries: ignoredFolderEntries[id] ?? [:],
      branchChanges: changeComparison(of: id).branchChanges,
    )
    // Read before the cache answers, so a render it answers still redraws on a landing.
    _ = fileTreeBuildLandings
    let landedListing = fileTreeListings[id]
    let landedChanges = fileTreeChanges[id]
    let cached = fileTreeCache[id]
    if let cached, cached.sources == sources,
      !(cached.awaitsListing && pendingFileTreeListings[id] == nil),
      !(cached.awaitsChanges && pendingFileTreeChanges[id] == nil)
    {
      return cached.tree
    }
    // A count moving, as an agent's every save does, keeps the listing.
    let key = FileTreeListing.Key(sources)
    let built =
      [cached?.tree.listing, landedListing].compactMap(\.self)
      .first { $0.key == key }
      ?? smallListing(sources, key: key)
    if built != nil {
      // The tree about to hold it keeps it now; a build still running for other
      // paths lands with nothing waiting for it, a started one not being stoppable.
      fileTreeListings[id] = nil
    } else {
      buildListingInTheBackground(sources, key: key, for: id)
    }
    let listing = built ?? cached?.tree.listing ?? landedListing ?? .empty
    let changes = treeChanges(
      sources,
      repositories: listing.repositories,
      kept: [cached?.tree.changes, landedChanges].compactMap(\.self),
      for: id,
    )
    let tree = FileTree(sources, listing: listing, changes: changes.changes)
    fileTreeCache[id] = FileTreeCacheEntry(
      sources: sources,
      tree: tree,
      awaitsListing: built == nil,
      awaitsChanges: !changes.isBuilt,
      quickSwitcherSearch: cached?.tree.listing.key == listing.key
        ? cached?.quickSwitcherSearch : nil,
    )
    return tree
  }

  /// The changed paths' half, reused while the paths hold; a set too large for a
  /// render is built off the main actor, the last one shown meanwhile.
  private func treeChanges(
    _ sources: FileTreeSources,
    repositories: Set<String>,
    kept: [FileTreeChanges],
    for id: Worktree.ID,
  )
    -> (changes: FileTreeChanges, isBuilt: Bool)
  {
    let paths = FileTreeChanges.paths(changedIn: sources)
    let built =
      kept.first { $0.isBuilt(from: paths, repositories: repositories) }
      ?? (paths.count < Self.builtInPlaceBelow
        ? FileTreeChanges(paths, repositories: repositories) : nil)
    if let built {
      fileTreeChanges[id] = nil
      return (built, true)
    }
    buildChangesInTheBackground(paths, repositories: repositories, for: id)
    return (kept.first ?? .empty, false)
  }

  private func smallListing(
    _ sources: FileTreeSources,
    key: FileTreeListing.Key,
  )
    -> FileTreeListing?
  {
    guard key.pathCount < Self.builtInPlaceBelow else { return nil }
    return FileTreeListing(sources, key: key)
  }

  /// A started build cannot be stopped, so another waits for it to land; the
  /// redraw its landing sets off asks for the newest key.
  private func buildListingInTheBackground(
    _ sources: FileTreeSources,
    key: FileTreeListing.Key,
    for id: Worktree.ID,
  ) {
    guard pendingFileTreeListings[id] == nil else { return }
    pendingFileTreeListings[id] = Task { @MainActor [weak self] in
      let listing = await runOnDispatch {
        let started = ContinuousClock.now
        var listing = FileTreeListing(sources, key: key)
        listing.buildCost = started.duration(to: .now)
        return listing
      }
      guard let self, !Task.isCancelled else { return }
      pendingFileTreeListings[id] = nil
      // Sources that moved back while it built leave nothing to show it.
      guard fileTreeCache[id]?.awaitsListing == true else { return }
      fileTreeListings[id] = listing
      fileTreeBuildLandings += 1
    }
  }

  /// One at a time, as a listing's build is.
  private func buildChangesInTheBackground(
    _ paths: Set<String>,
    repositories: Set<String>,
    for id: Worktree.ID,
  ) {
    guard pendingFileTreeChanges[id] == nil else { return }
    pendingFileTreeChanges[id] = Task { @MainActor [weak self] in
      let changes = await runOnDispatch { FileTreeChanges(paths, repositories: repositories) }
      guard let self, !Task.isCancelled else { return }
      pendingFileTreeChanges[id] = nil
      guard fileTreeCache[id]?.awaitsChanges == true else { return }
      fileTreeChanges[id] = changes
      fileTreeBuildLandings += 1
    }
  }
}
