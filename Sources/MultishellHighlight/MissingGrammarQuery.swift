/// A grammar's query file was in no bundle looked in: a resource bundle the
/// bundling script did not copy, or a grammar package that moved its queries.
struct MissingGrammarQuery: Error {
  let bundle: String
  let file: String
}
