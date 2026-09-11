import Foundation

/// An array whose elements decode one at a time, the rest dropped: a
/// synthesized `[Element]` fails whole on its first bad element.
struct LossyArray<Element: Decodable>: Decodable {
  let elements: [Element]

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var elements: [Element] = []
    while !container.isAtEnd {
      if let element = try? container.decode(Element.self) {
        elements.append(element)
      } else {
        // A failed decode leaves the index where it was; decoding a value
        // that reads nothing moves past the bad element.
        _ = try container.decode(Skipped.self)
      }
    }
    self.elements = elements
  }

  private struct Skipped: Decodable {
    init(from decoder: any Decoder) throws {}
  }
}

extension KeyedDecodingContainer {
  /// `decodeIfPresent` for a collection where one bad element must not fail
  /// the file. Absent or not an array at all reads as empty.
  func decodeLossy<Element: Decodable>(
    _ type: Element.Type, forKey key: Key
  ) -> [Element] {
    (try? decodeIfPresent(LossyArray<Element>.self, forKey: key))?.elements ?? []
  }
}
