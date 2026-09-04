import Foundation

/// An array whose elements decode one at a time, keeping the ones that
/// decode and dropping the rest.
///
/// A synthesized `[Element]` fails whole on its first bad element, and a
/// failed `Workspace` decode costs the user every project. A tab from a newer
/// build with a pane kind this one does not know, or one hand-edited id,
/// should cost that tab and nothing else.
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
