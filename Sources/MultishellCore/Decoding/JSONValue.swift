/// Any JSON, kept as read. For the keys of a committed file this build has
/// no field for, which an export writes back rather than drops.
enum JSONValue: Codable, Hashable, Sendable {
  case array([Self])
  case bool(Bool)
  case integer(Int)
  case null
  case number(Double)
  case object([String: Self])
  case string(String)

  init(from decoder: any Decoder) throws {
    let single = try decoder.singleValueContainer()
    if single.decodeNil() {
      self = .null
    } else if let value = try? single.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? single.decode(Int.self) {
      self = .integer(value)
    } else if let value = try? single.decode(Double.self) {
      self = .number(value)
    } else if let value = try? single.decode(String.self) {
      self = .string(value)
    } else if let value = try? single.decode([Self].self) {
      self = .array(value)
    } else {
      self = .object(try single.decode([String: Self].self))
    }
  }

  func encode(to encoder: any Encoder) throws {
    var single = encoder.singleValueContainer()
    switch self {
    case .null: try single.encodeNil()
    case .bool(let value): try single.encode(value)
    case .integer(let value): try single.encode(value)
    case .number(let value): try single.encode(value)
    case .string(let value): try single.encode(value)
    case .array(let value): try single.encode(value)
    case .object(let value): try single.encode(value)
    }
  }
}
