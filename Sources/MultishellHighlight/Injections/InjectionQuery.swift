import SwiftTreeSitter

/// The query that finds a markup host's injections, kept with the host it was built
/// for so a highlight never pairs it with another.
struct InjectionQuery: Sendable {
  let host: MarkupHost
  let query: Query
}
