import Foundation
import MultishellAppCore
import SwiftTreeSitter

/// Where an HTML, Svelte or Markdown tree holds another language. Our own query: Svelte's
/// injection file is Neovim's and inherits one no package ships.
enum HighlightInjections {
  private static let htmlQuery = "(script_element) @script (style_element) @style"

  private static let markdownQuery = "(fenced_code_block) @code_block (html_block) @html_block"

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

  static func query(for host: InjectionHost, in language: Language) throws -> Query {
    let source =
      switch host {
      case .markup(.html): htmlQuery
      case .markup(.svelte): svelteQuery
      case .markdown: markdownQuery
      }
    return try Query(language: language, data: Data(source.utf8))
  }

  /// Where `keptRanges` are given, only the injections that may reach one, though Svelte's
  /// expression language and Markdown's HTML blocks are read from the whole file.
  static func find(
    in tree: MutableTree,
    text: NSString,
    using injectionQuery: InjectionQuery,
    within keptRanges: [Range<Int>]?,
  ) -> HostInjections {
    switch injectionQuery.host {
    case .markup(let host):
      return markupInjections(
        from: captures(of: injectionQuery, in: tree, text: text, within: keptRanges),
        in: tree,
        text: text,
        host: host,
        within: keptRanges,
      )

    case .markdown:
      guard let root = tree.rootNode else { return HostInjections() }
      return markdownInjections(
        from: captures(of: injectionQuery, in: tree, text: text, within: nil),
        under: root,
        text: text,
        within: keptRanges,
      )
    }
  }

  private static func captures(
    of injectionQuery: InjectionQuery,
    in tree: MutableTree,
    text: NSString,
    within keptRanges: [Range<Int>]?,
  ) -> some Sequence<QueryCapture> {
    injectionQuery.query.captures(
      in: tree,
      within: keptRanges,
      matching: Predicate.Context(string: text as String),
    )
  }

  private static func markdownInjections(
    from captures: some Sequence<QueryCapture>,
    under root: Node,
    text: NSString,
    within keptRanges: [Range<Int>]?,
  ) -> HostInjections {
    var found = HostInjections()
    var htmlBlocks: [Node] = []
    for capture in captures {
      switch capture.name {
      case "code_block" where keptRanges?.hasRange(meeting: capture.range.integerRange) ?? true:
        found.add(FencedCodeBlock.injection(of: capture.node, in: text))

      case "html_block": htmlBlocks.append(capture.node)
      default: break
      }
    }
    let html = HTMLBlocks.injection(of: htmlBlocks, under: root, in: text)
    if let html, keptRanges.map(html.reaches(any:)) ?? true { found.add(html) }
    return found
  }

  private static func markupInjections(
    from captures: some Sequence<QueryCapture>,
    in tree: MutableTree,
    text: NSString,
    host: MarkupHost,
    within keptRanges: [Range<Int>]?,
  ) -> HostInjections {
    var found = HostInjections()
    guard let root = tree.rootNode else { return found }
    lazy var language = expressionLanguage(in: text)
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
