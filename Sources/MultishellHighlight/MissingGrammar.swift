import MultishellAppCore

/// A language with no entry in `HighlightGrammars`' table.
struct MissingGrammar: Error {
  let language: HighlightLanguage
}
