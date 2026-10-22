import MultishellAppCore
import SwiftTreeSitter

/// One highlight's grammars and parsers, so a Svelte file's injections neither take the shared
/// lock nor make a parser apiece; `nil` is one that failed, retried on the next highlight.
struct HighlightPassCache {
  var grammars: [HighlightLanguage: CompiledGrammar?] = [:]
  var parsers: [HighlightLanguage: Parser?] = [:]
}
