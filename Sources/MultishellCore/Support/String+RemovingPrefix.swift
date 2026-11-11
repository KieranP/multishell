extension String {
  /// This without `prefix`, or `nil` where it does not start with it. By byte: a
  /// separator ending `prefix` joins a combining mark after it into one `Character`.
  public func removingPrefix(_ prefix: String) -> String? {
    guard utf8.starts(with: prefix.utf8) else { return nil }
    return String(Substring(utf8.dropFirst(prefix.utf8.count)))
  }
}
