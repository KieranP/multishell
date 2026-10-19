import MultishellAppCore
import SwiftTreeSitter

/// A language's grammar with its highlights and injection queries compiled against
/// it, which costs about 100 ms, so it is made once a language and kept.
struct CompiledGrammar: Sendable {
  let language: Language
  let query: Query
  let injectionQuery: InjectionQuery?
  let captureRoles: [HighlightRole?]

  init(
    language: Language,
    query: Query,
    injectionQuery: InjectionQuery?,
    rolesFor highlighted: HighlightLanguage,
  ) {
    self.language = language
    self.query = query
    self.injectionQuery = injectionQuery
    // By capture index, so a file's 200,000 captures do not map their names to roles again each.
    captureRoles = (0..<query.captureCount).map { index in
      query.captureName(for: index).flatMap { name in
        HighlightCaptureRoles.role(forCapture: name, in: highlighted)
      }
    }
  }
}
