import Foundation

extension JSONEncoder {
  /// One newline-terminated line of compact JSON, for the socket: a report, a
  /// request and a reply alike.
  static func socketLine(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
  }
}
