/// Enough of an encoder for the shapes OpenCode hands a plugin: strings and
/// dictionaries of them, nested.
struct AnyEncodable: Encodable {
  private let encode: (any Encoder) throws -> Void

  init(_ value: String) { encode = { try value.encode(to: $0) } }
  init(_ value: [String: String]) { encode = { try value.encode(to: $0) } }
  init(_ value: [String: Self]) { encode = { try value.encode(to: $0) } }
  init(_ value: [String]) { encode = { try value.encode(to: $0) } }
  init(_ value: [Self]) { encode = { try value.encode(to: $0) } }
  init(_ value: Bool) { encode = { try value.encode(to: $0) } }

  func encode(to encoder: any Encoder) throws { try encode(encoder) }
}
