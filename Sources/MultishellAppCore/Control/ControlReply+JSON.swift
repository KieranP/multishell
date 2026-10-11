import Foundation
import MultishellCore

extension ControlReply {
  /// Indented and sorted, as an agent reads it and a diff compares it. A
  /// non-finite reading is spelled out, the one thing that would fail it.
  static func json(_ value: some Encodable) -> Self {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
      positiveInfinity: "inf",
      negativeInfinity: "-inf",
      nan: "nan",
    )
    guard let data = try? encoder.encode(value) else { return .refused(.replyNotEncoded) }
    return .output(String(decoding: data, as: UTF8.self))
  }

  /// What JSONSerialization takes, a bare value included, for the settings.
  /// Asked first: it raises an exception on anything else, which `try?` misses.
  static func jsonObject(_ value: Any) -> Self {
    let options: JSONSerialization.WritingOptions = [
      .prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes,
    ]
    guard JSONSerialization.isValidJSONObject([value]),
      let data = try? JSONSerialization.data(withJSONObject: value, options: options)
    else { return .refused(.replyNotEncoded) }
    return .output(String(decoding: data, as: UTF8.self))
  }
}
