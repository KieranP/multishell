/// An array whose elements decode one at a time, the rest dropped: a
/// synthesized `[Element]` fails whole on its first bad element.
public struct LossyArray<Element: Decodable>: Decodable {
  private struct Skipped: Decodable {
    init(from decoder: any Decoder) throws {}
  }

  public let elements: [Element]

  public init(from decoder: any Decoder) throws {
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
}
