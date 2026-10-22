import Foundation
import MultishellAppCore
import SwiftTreeSitter
import TreeSitterBash
import TreeSitterC
import TreeSitterCPP
import TreeSitterCSS
import TreeSitterCSharp
import TreeSitterGo
import TreeSitterHTML
import TreeSitterJSON
import TreeSitterJava
import TreeSitterJavaScript
import TreeSitterKotlin
import TreeSitterMake
import TreeSitterMarkdown
import TreeSitterPHP
import TreeSitterPython
import TreeSitterRuby
import TreeSitterRust
import TreeSitterSCSS
import TreeSitterSql
import TreeSitterSvelte
import TreeSitterSwift
import TreeSitterTOML
import TreeSitterTSX
import TreeSitterTypeScript
import TreeSitterYAML
import TreeSitterZig
import os

/// Each language's grammar and query files. TypeScript's extends JavaScript's, C++'s
/// C's, SCSS's CSS's and Svelte's HTML's: both are read in that order, the later winning.
enum HighlightGrammars {
  /// A query file a grammar package ships, by the package's bundle.
  private struct QueryFile: Sendable {
    let bundle: String
    let name: String

    static func highlights(
      in package: String,
      target: String? = nil,
      name: String = "highlights.scm",
    ) -> Self {
      Self(bundle: "\(package)_\(target ?? package)", name: name)
    }
  }

  /// A language's grammar, loaded when first compiled, and its query files.
  private struct GrammarSource: Sendable {
    let load: @Sendable () -> OpaquePointer
    let queries: [QueryFile]

    init(_ load: @escaping @Sendable () -> OpaquePointer, _ queries: [QueryFile]) {
      self.load = load
      self.queries = queries
    }
  }

  private static let logger = Logger(subsystem: AppBundle.identifier, category: "highlight")

  private static let javaScript = QueryFile.highlights(in: "TreeSitterJavaScript")
  private static let c = QueryFile.highlights(in: "TreeSitterC")
  private static let css = QueryFile.highlights(in: "TreeSitterCSS")
  private static let html = QueryFile.highlights(in: "TreeSitterHTML")
  private static let jsx = QueryFile.highlights(
    in: "TreeSitterJavaScript",
    name: "highlights-jsx.scm",
  )

  /// A table rather than a switch, 26 cases being past the lint's complexity;
  /// `everyGrammarCompilesWithItsQuery` checks every language has an entry.
  private static let sources: [HighlightLanguage: GrammarSource] = [
    .bash: GrammarSource({ tree_sitter_bash() }, [.highlights(in: "TreeSitterBash")]),
    .c: GrammarSource({ tree_sitter_c() }, [c]),
    .cpp: GrammarSource({ tree_sitter_cpp() }, [c, .highlights(in: "TreeSitterCPP")]),
    .cSharp: GrammarSource({ tree_sitter_c_sharp() }, [.highlights(in: "TreeSitterCSharp")]),
    .css: GrammarSource({ tree_sitter_css() }, [css]),
    .golang: GrammarSource({ tree_sitter_go() }, [.highlights(in: "TreeSitterGo")]),
    .html: GrammarSource({ tree_sitter_html() }, [html]),
    .java: GrammarSource({ tree_sitter_java() }, [.highlights(in: "TreeSitterJava")]),
    .javaScript: GrammarSource({ tree_sitter_javascript() }, [javaScript, jsx]),
    .json: GrammarSource({ tree_sitter_json() }, [.highlights(in: "TreeSitterJSON")]),
    .kotlin: GrammarSource({ tree_sitter_kotlin() }, [.highlights(in: "TreeSitterKotlin")]),
    .makefile: GrammarSource({ tree_sitter_make() }, [.highlights(in: "TreeSitterMake")]),
    .markdown: GrammarSource({ tree_sitter_markdown() }, [.highlights(in: "TreeSitterMarkdown")]),
    .php: GrammarSource({ tree_sitter_php() }, [.highlights(in: "TreeSitterPHP")]),
    .python: GrammarSource({ tree_sitter_python() }, [.highlights(in: "TreeSitterPython")]),
    .ruby: GrammarSource({ tree_sitter_ruby() }, [.highlights(in: "TreeSitterRuby")]),
    .rust: GrammarSource({ tree_sitter_rust() }, [.highlights(in: "TreeSitterRust")]),
    .scss: GrammarSource({ tree_sitter_scss() }, [css, .highlights(in: "TreeSitterSCSS")]),
    .sql: GrammarSource({ tree_sitter_sql() }, [.highlights(in: "TreeSitterSql")]),
    .svelte: GrammarSource({ tree_sitter_svelte() }, [html, .highlights(in: "TreeSitterSvelte")]),
    .swift: GrammarSource({ tree_sitter_swift() }, [.highlights(in: "TreeSitterSwift")]),
    .toml: GrammarSource({ tree_sitter_toml() }, [.highlights(in: "TreeSitterTOML")]),
    .tsx: GrammarSource(
      { tree_sitter_tsx() },
      [javaScript, jsx, .highlights(in: "TreeSitterTypeScript", target: "TreeSitterTSX")],
    ),
    .typeScript: GrammarSource(
      { tree_sitter_typescript() },
      [javaScript, .highlights(in: "TreeSitterTypeScript")],
    ),
    .yaml: GrammarSource({ tree_sitter_yaml() }, [.highlights(in: "TreeSitterYAML")]),
    .zig: GrammarSource({ tree_sitter_zig() }, [.highlights(in: "TreeSitterZig")]),
  ]

  static func compile(_ language: HighlightLanguage) throws -> CompiledGrammar {
    guard let grammar = sources[language] else { throw MissingGrammar(language: language) }
    let shipped = try grammar.queries.map { file in
      guard let text = GrammarQueries.query(file.name, inBundle: file.bundle) else {
        throw MissingGrammarQuery(bundle: file.bundle, file: file.name)
      }
      return text
    }
    let corrections = HighlightQueryCorrections.query(for: language).map { [$0] } ?? []
    let source = (shipped + corrections).joined(separator: "\n")
    let compiled = Language(language: grammar.load())
    return CompiledGrammar(
      language: compiled,
      query: try Query(language: compiled, data: Data(source.utf8)),
      injectionQuery: injectionQuery(for: language, in: compiled),
      rolesFor: language,
    )
  }

  /// A broken injection query costs only the injections, not the file's colour, so
  /// it is logged rather than thrown; `everyInjectionQueryCompilesWhereALanguageHasOne` tests it.
  private static func injectionQuery(
    for language: HighlightLanguage,
    in compiled: Language,
  ) -> InjectionQuery? {
    guard let host = MarkupHost(language) else { return nil }
    do {
      let query = try HighlightInjections.query(for: host, in: compiled)
      return InjectionQuery(host: host, query: query)
    } catch {
      logger.error(
        "\(String(describing: language), privacy: .public) injection query failed: \(error, privacy: .public)"
      )
      return nil
    }
  }
}
