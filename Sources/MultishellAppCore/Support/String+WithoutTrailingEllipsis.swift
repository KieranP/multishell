extension String {
  /// A menu title as AppKit's own items match it, with or without its "…".
  public var withoutTrailingEllipsis: String {
    var trimmed = self
    for ellipsis in ["…", "..."] where trimmed.hasSuffix(ellipsis) {
      trimmed.removeLast(ellipsis.count)
    }
    return trimmed
  }
}
