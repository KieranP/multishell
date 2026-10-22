import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// Where an HTML or Svelte tree holds another language. Our own query: Svelte's
/// injection file is Neovim's and inherits one no package ships.
enum HighlightInjections {
  private static let htmlQuery = "(script_element) @script (style_element) @style"

  /// Each node a `{…}` expression sits in whole. An each's parameter and an
  /// await's head are cut apart, and a shorthand attribute keeps its colour.
  private static let expressionParents = [
    "expression", "if_start", "else_if_start", "key_start", "html_tag", "const_tag",
    "debug_tag", "render_tag",
  ]

  private static let expressionPatterns = expressionParents.map { parent in
    "(\(parent) (svelte_raw_text) @expression)"
  }

  private static let sveltePatterns = [
    "(each_start identifier: (svelte_raw_text) @expression)",
    "(each_start parameter: (svelte_raw_text) @each_parameter)",
    "(await_start (svelte_raw_text) @await_head)", "(snippet_start) @snippet",
    "(then_start (svelte_raw_text) @pattern)", "(catch_start (svelte_raw_text) @pattern)",
  ]

  private static let svelteQuery = ([htmlQuery] + expressionPatterns + sveltePatterns)
    .joined(separator: "\n")

  static func query(for host: MarkupHost, in language: Language) throws -> Query {
    let source =
      switch host {
      case .html: htmlQuery
      case .svelte: svelteQuery
      }
    return try Query(language: language, data: Data(source.utf8))
  }

  /// Where `keptRanges` are given, only the injections that may reach one, though a
  /// Svelte expression's language is still read from the whole file.
  static func find(
    in tree: MutableTree,
    text: NSString,
    using injectionQuery: InjectionQuery,
    within keptRanges: [Range<Int>]?,
  ) -> HostInjections {
    var found = HostInjections()
    guard let root = tree.rootNode else { return found }
    let host = injectionQuery.host
    lazy var language = expressionLanguage(in: text)
    let captures = injectionQuery.query.captures(
      in: tree,
      within: keptRanges,
      matching: Predicate.Context(string: text as String),
    )
    for capture in captures {
      let node = capture.node
      switch capture.name {
      case "script":
        found.add(body(of: node, in: text, host: host, as: ElementBodyLanguage.script))

      case "style":
        found.add(body(of: node, in: text, host: host, as: ElementBodyLanguage.style))

      case "snippet": found.add(snippetSignature(node, as: language))
      case "await_head": found.add(awaitHead(node, in: text, as: language))
      case "each_parameter": found.add(eachParameter(node, in: text, as: language))
      case "expression": found.add(expression(node, as: language))
      case "pattern": found.add(pattern(node, as: language))
      default: break
      }
    }
    found.injections += attributeInjections(
      under: root,
      text: text,
      host: host,
      within: keptRanges,
    )
    return found
  }

  private static func body(
    of element: Node,
    in text: NSString,
    host: MarkupHost,
    as language: (_ attributes: [String: String], _ host: MarkupHost) -> HighlightLanguage?,
  ) -> Injection? {
    guard let language = language(attributes(of: element, in: text, host: host), host),
      let body = element.children.first(where: { $0.nodeType == "raw_text" }),
      body.range.length > 0
    else { return nil }
    return Injection(range: body.range.integerRange, language: language)
  }
}
