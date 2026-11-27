import MultishellCore

/// The header's folder and name, split by scalar as the tree splits: a name
/// starting with a combining mark would join the slash before it.
extension AllChangesFileChange {
  /// Empty at the worktree's root.
  public var folder: String { path.slashSeparatedFolder }

  public var fileName: String { path.lastSlashSeparatedPart }
}
