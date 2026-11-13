extension String {
  /// Its first `maxLength` characters, each one a file name or socket path cannot
  /// hold made `-`.
  public func portableName(maxLength: Int) -> String {
    String(prefix(maxLength).map { $0.isPortableNameCharacter ? $0 : "-" })
  }
}
