@testable import MultishellAppCore

extension FileTree {
  init(_ sources: FileTreeSources) {
    let key = FileTreeListing.Key(sources)
    self.init(sources, listing: FileTreeListing(sources, key: key), reusingChangesOf: nil)
  }
}
