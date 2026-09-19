import Foundation

extension JSONEncoder {
  /// For a file someone may read or diff: indented, keys sorted. Every writer
  /// shares it; `SharedProjectSettings.digest` is why the options stay put.
  static func forFile() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}
