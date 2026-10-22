import SwiftTreeSitter

extension Node {
  /// An `attribute`'s value as written, with its quotes where it has them.
  var attributeValueAsWritten: Node? {
    children.first { ["attribute_value", "quoted_attribute_value"].contains($0.nodeType) }
  }

  /// An `attribute`'s value: `lang=ts` holds it directly, `lang="ts"` inside its quotes.
  var attributeValue: Node? {
    guard let written = attributeValueAsWritten else { return nil }
    guard written.nodeType == "quoted_attribute_value" else { return written }
    return written.children.first { $0.nodeType == "attribute_value" }
  }
}
