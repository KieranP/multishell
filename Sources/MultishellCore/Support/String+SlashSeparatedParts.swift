extension String {
  /// The non-empty parts between slashes, split by scalar: a name starting with
  /// a combining mark joins the slash before it into one `Character`.
  public var slashSeparatedParts: [Substring] {
    unicodeScalars.split(separator: "/").map(Substring.init)
  }
}
