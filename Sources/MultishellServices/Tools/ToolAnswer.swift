import Foundation
import MultishellCore

/// A tool's JSON answer, or the one failure every read gives for output it
/// cannot read.
enum ToolAnswer {
  static func decode<Value: Decodable>(
    _ type: Value.Type,
    from json: Data,
    with decoder: JSONDecoder = JSONDecoder(),
  ) throws -> Value {
    guard let value = try? decoder.decode(type, from: json) else {
      throw ServiceReadFailure.failed(t("integration.unreadable-answer"))
    }
    return value
  }
}
