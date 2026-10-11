extension String {
  /// The engine's own test of a search left as it is, `std.ascii.eqlIgnoreCase`.
  func isSameSearchText(as other: String) -> Bool {
    func folded(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
    return utf8.count == other.utf8.count
      && zip(utf8, other.utf8).allSatisfy { folded($0) == folded($1) }
  }
}
