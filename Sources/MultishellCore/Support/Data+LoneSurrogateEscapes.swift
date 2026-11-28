import Foundation

extension Data {
  /// JSON text with each `\uD800`-`\uDFFF` escape outside a high-then-low pair
  /// turned into `�`, which Foundation's parser takes where it refused the whole text.
  var withLoneSurrogateEscapesReplaced: Data {
    let bytes = [UInt8](self)
    var replaced: [UInt8] = []
    replaced.reserveCapacity(bytes.count)
    var index = 0
    while index < bytes.count {
      guard bytes[index] == UInt8(ascii: "\\"), index + 1 < bytes.count else {
        replaced.append(bytes[index])
        index += 1
        continue
      }
      guard let unit = Self.surrogateEscape(in: bytes, at: index) else {
        replaced += bytes[index...index + 1]
        index += 2
        continue
      }
      if unit < 0xDC00, let low = Self.surrogateEscape(in: bytes, at: index + 6), low >= 0xDC00 {
        replaced += bytes[index..<index + 12]
        index += 12
      } else {
        replaced += Array(#"�"#.utf8)
        index += 6
      }
    }
    return Data(replaced)
  }

  /// The UTF-16 unit a `\uXXXX` escape at `start` names, where it is a surrogate.
  private static func surrogateEscape(in bytes: [UInt8], at start: Int) -> UInt16? {
    guard start + 6 <= bytes.count, bytes[start] == UInt8(ascii: "\\"),
      bytes[start + 1] == UInt8(ascii: "u"),
      let unit = UInt16(String(decoding: bytes[start + 2..<start + 6], as: UTF8.self), radix: 16),
      (0xD800...0xDFFF).contains(unit)
    else { return nil }
    return unit
  }
}
