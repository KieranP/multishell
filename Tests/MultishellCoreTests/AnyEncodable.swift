/// Enough of an encoder for the shapes OpenCode hands a plugin: strings and
/// dictionaries of them, nested.
struct AnyEncodable: Encodable {
  private let encode: (Encoder) throws -> Void

  init(_ value: String) { encode = { try value.encode(to: $0) } }
  init(_ value: [String: String]) { encode = { try value.encode(to: $0) } }
  init(_ value: [String: AnyEncodable]) { encode = { try value.encode(to: $0) } }
  init(_ value: [String]) { encode = { try value.encode(to: $0) } }
  init(_ value: [AnyEncodable]) { encode = { try value.encode(to: $0) } }
  init(_ value: Bool) { encode = { try value.encode(to: $0) } }

  func encode(to encoder: Encoder) throws { try encode(encoder) }
}
