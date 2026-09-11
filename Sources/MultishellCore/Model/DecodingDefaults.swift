import Foundation

/// Reads a key that may not be there, the verb saying what a wrong type
/// costs; see docs/design/state-and-store.md.
extension KeyedDecodingContainer {
  /// Absent reads as `fallback`; a wrong type throws. The default for what
  /// the app wrote: failing is what moves the file aside as `.broken.json`.
  func decode<T: Decodable>(
    _ type: T.Type, forKey key: Key, or fallback: @autoclosure () -> T
  ) throws -> T {
    try decodeIfPresent(type, forKey: key) ?? fallback()
  }

  /// Absent or unreadable reads as `fallback`, nothing throws. For a value
  /// this build may legitimately not understand, such as a newer enum case.
  func decodeTolerantly<T: Decodable>(
    _ type: T.Type, forKey key: Key, or fallback: @autoclosure () -> T
  ) -> T {
    (try? decodeIfPresent(type, forKey: key)) ?? fallback()
  }

  /// The same where the field's absence is itself the answer, `nil` meaning
  /// "not set" rather than "use a default".
  func decodeTolerantly<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
    // `try?` flattens the nested optional (SE-0230), so an absent key and an
    // unreadable one both arrive here as `nil`, which is what this wants.
    try? decodeIfPresent(type, forKey: key)
  }
}
