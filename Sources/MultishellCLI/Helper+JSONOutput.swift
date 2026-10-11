import Foundation

extension Helper {
  /// Indented and sorted as the app's own answers are, so every command a
  /// script reads prints alike.
  static func jsonText(_ object: Any) throws -> String {
    let data = try JSONSerialization.data(
      withJSONObject: object,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes],
    )
    return String(decoding: data, as: UTF8.self)
  }

  /// An answer's JSON as Foundation reads it; `nil` where there is none.
  static func jsonValue(_ text: String?) -> Any? {
    text.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
  }

  static func printJSON(_ object: Any) throws {
    print(try jsonText(object))
  }
}
