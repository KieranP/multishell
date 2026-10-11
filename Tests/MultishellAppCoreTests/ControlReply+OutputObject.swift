import Foundation
import MultishellCore

extension ControlReply {
  /// The printed JSON read back, `nil` for a reply that prints nothing.
  var outputObject: Any? {
    output.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
  }

  var outputFields: [String: Any] { outputObject as? [String: Any] ?? [:] }
}
