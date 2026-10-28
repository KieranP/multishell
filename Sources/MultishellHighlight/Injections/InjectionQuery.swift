import SwiftTreeSitter

/// The query that finds a host's injections, kept with the host it was built
/// for so a highlight never pairs it with another.
struct InjectionQuery: Sendable {
  let host: InjectionHost
  let query: Query
}
