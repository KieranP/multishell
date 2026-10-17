extension String {
  /// Split at `\n` and `\r\n` alike: Swift reads `\r\n` as one character, so
  /// splitting on `\n` alone kept a CRLF text whole.
  public func lines() -> [Substring] {
    split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
  }
}
