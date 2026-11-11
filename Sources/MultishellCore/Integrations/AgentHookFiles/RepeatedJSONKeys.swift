/// Whether an object names a key twice, compared as spelled. JSONSerialization keeps
/// the first and the agents' `JSON.parse` the last, so a rewrite kept the ignored one.
enum RepeatedJSONKeys {
  static func occur(in json: String) -> Bool {
    let bytes = Array(json.utf8)
    // One entry per open container: an object's keys so far, `nil` for an array.
    var containers: [Set<ArraySlice<UInt8>>?] = []
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
          guard keys.insert(bytes[start..<min(index, bytes.count)]).inserted else { return true }
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
}
