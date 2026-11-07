import MultishellAppCore
import SwiftTreeSitter

/// A language's grammar with its highlights and injection queries compiled against
/// it, which costs about 100 ms, so it is made once a language and kept.
struct CompiledGrammar: Sendable {
  let language: Language
  let query: Query
  let injectionQuery: InjectionQuery?
  let localNames: LocalNamesQuery?
  let captureRoles: [HighlightRole?]
  let embeddedCodeCaptures: Set<Int>

  init(
    language: Language,
    query: Query,
    injectionQuery: InjectionQuery?,
    rolesFor highlighted: HighlightLanguage,
    localNames: LocalNamesQuery? = nil,
  ) {
    self.language = language
    self.query = query
    self.injectionQuery = injectionQuery
    self.localNames = localNames
    // By capture index, so a file's 200,000 captures do not map their names to roles again each.
    captureRoles = (0..<query.captureCount).map { index in
      query.captureName(for: index).flatMap { name in
        HighlightCaptureRoles.role(forCapture: name, in: highlighted)
      }
    }
    embeddedCodeCaptures = Set(
      (0..<query.captureCount).filter { index in
        query.captureName(for: index).map(HighlightCaptureRoles.marksEmbeddedCode) ?? false
      }
    )
  }
}
