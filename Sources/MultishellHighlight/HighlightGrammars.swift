import Foundation
import MultishellAppCore
import SwiftTreeSitter
import TreeSitterBash
import TreeSitterC
import TreeSitterCPP
import TreeSitterCSharp
import TreeSitterGo
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
import TreeSitterSql
import TreeSitterSwift
import TreeSitterTOML
import TreeSitterTSX
import TreeSitterTypeScript
import TreeSitterYAML
import TreeSitterZig

/// Each language's grammar and query files. TypeScript's extends JavaScript's
/// and C++'s extends C's, so both are read, in that order, the later winning.
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

  private static let javaScript = QueryFile.highlights(in: "TreeSitterJavaScript")
  private static let c = QueryFile.highlights(in: "TreeSitterC")
  private static let jsx = QueryFile.highlights(
    in: "TreeSitterJavaScript",
    name: "highlights-jsx.scm",
  )

  /// A table rather than a switch, 22 cases being past the lint's complexity;
  /// `everyGrammarCompilesWithItsQuery` checks every language has an entry.
  private static let sources: [HighlightLanguage: GrammarSource] = [
    .bash: GrammarSource({ tree_sitter_bash() }, [.highlights(in: "TreeSitterBash")]),
    .c: GrammarSource({ tree_sitter_c() }, [c]),
    .cpp: GrammarSource({ tree_sitter_cpp() }, [c, .highlights(in: "TreeSitterCPP")]),
    .cSharp: GrammarSource({ tree_sitter_c_sharp() }, [.highlights(in: "TreeSitterCSharp")]),
    .golang: GrammarSource({ tree_sitter_go() }, [.highlights(in: "TreeSitterGo")]),
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
    .sql: GrammarSource({ tree_sitter_sql() }, [.highlights(in: "TreeSitterSql")]),
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
    let source = try grammar.queries.map { file in
      guard let text = GrammarQueries.query(file.name, inBundle: file.bundle) else {
        throw MissingGrammarQuery(bundle: file.bundle, file: file.name)
      }
      return text
    }.joined(separator: "\n")
    let compiled = Language(language: grammar.load())
    return CompiledGrammar(
      language: compiled,
      query: try Query(language: compiled, data: Data(source.utf8)),
    )
  }
}
