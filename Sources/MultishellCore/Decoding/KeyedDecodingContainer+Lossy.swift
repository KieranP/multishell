extension KeyedDecodingContainer {
  /// `decodeIfPresent` for a collection where one bad element must not fail
  /// the file. Absent or not an array at all reads as empty.
  func decodeLossy<Element: Decodable>(
    _ type: Element.Type, forKey key: Key
  ) -> [Element] {
    (try? decodeIfPresent(LossyArray<Element>.self, forKey: key))?.elements ?? []
  }
}
