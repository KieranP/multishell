extension FileTreeRow {
  /// Lit where it is the file whose tab is in front of the focused group.
  func isShown(whenFileInFrontIs path: String?) -> Bool {
    !isFolder && self.path == path
  }
}
