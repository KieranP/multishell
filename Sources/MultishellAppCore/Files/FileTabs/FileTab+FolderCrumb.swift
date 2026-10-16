import MultishellCore

extension FileTab {
  /// `Sources › App ›`: the folders above the file as its bar shows them,
  /// `nil` for a file at the worktree's top.
  public var folderCrumb: String? {
    let folders = path.split(separator: "/").dropLast()
    guard !folders.isEmpty else { return nil }
    return folders.joined(separator: " › ") + " ›"
  }
}
