import SwiftTreeSitter

/// A language's grammar with its highlights query compiled against it, which
/// costs about 100 ms, so it is made once a language and kept.
struct CompiledGrammar: Sendable {
  let language: Language
  let query: Query
}
