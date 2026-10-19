import Foundation
import MultishellAppCore
import SwiftTreeSitter

extension HighlightInjections {
  /// The attributes HTML reads a body's language from, the only values decoded.
  private static let languageAttributeNames: Set<String> = ["type", "language"]

  /// By name as the host looks it up; a bare attribute's value is empty, and a
  /// repeated name keeps its first value.
  static func attributes(
    of element: Node,
    in text: NSString,
    host: MarkupHost,
  ) -> [String: String] {
    guard let tag = element.children.first(where: { $0.nodeType == "start_tag" }) else {
      return [:]
    }
    let readsAsABrowser = host.readsAttributesAsABrowserDoes
    var found: [String: String] = [:]
    for attribute in tag.children where attribute.nodeType == "attribute" {
      guard let nameNode = attribute.children.first(where: { $0.nodeType == "attribute_name" })
      else { continue }
      let writtenName = text.substring(with: nameNode.range)
      let name = readsAsABrowser ? writtenName.lowercased() : writtenName
      guard found[name] == nil else { continue }
      let isRead = readsAsABrowser || isEqualsSignUnspaced(in: attribute, after: nameNode)
      let value =
        isRead ? attribute.attributeValue.map { text.substring(with: $0.range) } ?? "" : ""
      let decodes =
        readsAsABrowser && languageAttributeNames.contains(name) && value.contains("&")
      found[name] = decodes ? CharacterReferences.decodedText(value) : value
    }
    return found
  }

  private static func isEqualsSignUnspaced(in attribute: Node, after name: Node) -> Bool {
    attribute.attributeValueAsWritten?.range.location == name.range.integerRange.upperBound + 1
  }
}
