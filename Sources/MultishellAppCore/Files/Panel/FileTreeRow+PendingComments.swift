extension FileTreeRow {
  /// Its file's comments to send; a folder takes none, though a file replaced by
  /// a folder of its name shares its path.
  public func pendingComments(in countsByPath: [String: Int]) -> Int {
    isFolder ? 0 : countsByPath[path] ?? 0
  }
}
