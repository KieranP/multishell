import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// An injection's body between its prefix and suffix, parsed as its grammar reads it.
struct WrappedInjection {
  private static let commentOpener = "/*"
  private static let commentCloser = "*/"

  let text: String
  let tree: MutableTree

  /// A `/*` a CSS body leaves open would swallow the suffix, so it is closed first where
  /// that parses clean: CSS ends an open comment at the end of its input, JavaScript errs.
  static func parsed(_ body: String, in injection: Injection, parser: Parser) -> Self? {
    let wrapped = injection.prefix + body + injection.suffix
    let input = SyntaxHighlighter.grammarInput(from: wrapped, language: injection.language)
    guard let tree = parser.parse(input) else { return nil }
    guard injection.language == .css, tree.rootNode?.hasError == true, leavesCommentOpen(body)
    else { return Self(text: wrapped, tree: tree) }
    let closed = injection.prefix + body + commentCloser + injection.suffix
    guard let closedTree = parser.parse(closed), closedTree.rootNode?.hasError == false else {
      return Self(text: wrapped, tree: tree)
    }
    return Self(text: closed, tree: closedTree)
  }

  /// Read forward, as CSS reads it, so the `/*` inside `*/*` opens nothing.
  static func leavesCommentOpen(_ body: String) -> Bool {
    var rest = body[...]
    while let opener = rest.range(of: commentOpener) {
      guard let closer = rest[opener.upperBound...].range(of: commentCloser) else { return true }
      rest = rest[closer.upperBound...]
    }
    return false
  }
}
