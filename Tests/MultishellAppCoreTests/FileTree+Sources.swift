@testable import MultishellAppCore

extension FileTree {
  init(_ sources: FileTreeSources) {
    let key = FileTreeListing.Key(sources)
    let listing = FileTreeListing(sources, key: key)
    let changes = FileTreeChanges(
      FileTreeChanges.paths(changedIn: sources),
      repositories: listing.repositories,
    )
    self.init(sources, listing: listing, changes: changes)
  }
}
