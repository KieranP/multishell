extension String {
  /// Cut to `limit` characters with an ellipsis after, or unchanged if it fits.
  func truncated(to limit: Int) -> String {
    count > limit ? prefix(limit) + "…" : self
  }
}
