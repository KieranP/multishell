import Foundation

extension JSONEncoder {
  /// For a file someone may read or diff: indented, keys sorted, a `/` left bare.
  /// A change to the options shows in a committed `.multishell.json`'s next diff.
  static func forFile() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }
}
