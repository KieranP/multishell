extension String {
  /// The non-empty parts between slashes, split by scalar: a name starting with
  /// a combining mark joins the slash before it into one `Character`.
  public var slashSeparatedParts: [Substring] {
    unicodeScalars.split(separator: "/").map(Substring.init)
  }

  /// The last part, the whole string where there is none.
  public var lastSlashSeparatedPart: String {
    slashSeparatedParts.last.map(Self.init) ?? self
  }

  /// Every part but the last, empty for a path at the root.
  public var slashSeparatedFolder: String {
    slashSeparatedParts.dropLast().joined(separator: "/")
  }
}
