import Foundation

/// Whether an object names a key twice, compared once escapes are decoded. JSONSerialization
/// keeps the first and the agents' `JSON.parse` the last, so a rewrite kept the ignored one.
enum RepeatedJSONKeys {
  static func occur(in json: String) -> Bool {
    let bytes = Array(json.utf8)
    // One entry per open container: an object's keys so far, `nil` for an array.
    var containers: [Set<String>?] = []
    var expectsKey = false
    var index = 0
    while index < bytes.count {
      switch bytes[index] {
      case UInt8(ascii: "\""):
        let start = index
        index += 1
        while index < bytes.count, bytes[index] != UInt8(ascii: "\"") {
          index += bytes[index] == UInt8(ascii: "\\") ? 2 : 1
        }
        if expectsKey, var keys = containers.last ?? nil {
          guard keys.insert(decodedKey(bytes[start..<min(index + 1, bytes.count)])).inserted else {
            return true
          }
          containers[containers.count - 1] = keys
          expectsKey = false
        }

      case UInt8(ascii: "{"):
        containers.append([])
        expectsKey = true

      case UInt8(ascii: "["):
        containers.append(nil)
        expectsKey = false

      case UInt8(ascii: "}"), UInt8(ascii: "]"):
        _ = containers.popLast()
        expectsKey = false

      case UInt8(ascii: ","):
        expectsKey = (containers.last ?? nil) != nil

      default: break
      }
      index += 1
    }
    return false
  }

  /// `quoted` runs from the opening quote to the closing one. A key left
  /// unterminated stays as spelled; the parse after this refuses the file.
  private static func decodedKey(_ quoted: ArraySlice<UInt8>) -> String {
    let isClosed = quoted.count > 1 && quoted.last == UInt8(ascii: "\"")
    let spelled = String(decoding: quoted.dropFirst().dropLast(isClosed ? 1 : 0), as: UTF8.self)
    guard isClosed, spelled.contains("\\") else { return spelled }
    let decoded = try? JSONSerialization.jsonObject(with: Data(quoted), options: .fragmentsAllowed)
    return decoded as? String ?? spelled
  }
}
