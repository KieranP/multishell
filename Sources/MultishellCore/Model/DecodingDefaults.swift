import Foundation

/// Reads a key that may not be there, in the two ways this app needs.
///
/// Every persisted field decodes with a default, so a state file written
/// before the field existed still loads; see `Workspace.init(from:)`. What
/// differs between fields is what a key of the *wrong* type should cost, and
/// that decision was previously carried by the difference between `try` and
/// `try?` at each line. The verb carries it here: `decode` fails the file,
/// `decodeTolerantly` does not. `or:` is the same fallback value in both.
///
/// The verb and not an argument label, because these lines wrap, and a label
/// landing on the second line is as easy to skip as the `try?` was.
///
/// `decodeLossy` in `LossyArray.swift` is the third way: a collection whose
/// bad elements are dropped one at a time.
extension KeyedDecodingContainer {
  /// Absent reads as `fallback`; a key of the wrong type throws.
  ///
  /// The default for anything the app itself wrote. A file it cannot parse is
  /// worth failing over, because failing is what moves it aside as
  /// `.broken.json` rather than replacing it with an empty one.
  func decode<T: Decodable>(
    _ type: T.Type, forKey key: Key, or fallback: @autoclosure () -> T
  ) throws -> T {
    try decodeIfPresent(type, forKey: key) ?? fallback()
  }

  /// Absent *or* unreadable reads as `fallback`, and nothing throws.
  ///
  /// For a value this build may legitimately not understand: an enum case a
  /// newer build named, a date in a shape it did not write, a toggle someone
  /// edited by hand. Costs that one value and leaves the rest of the file.
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
