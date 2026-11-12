/// One item of a note for an agent: what it is about, the code it quotes and
/// what to do.
struct AgentHandoffEntry: Equatable, Sendable {
  /// A file and its lines, or the name of what has no file, such as a check.
  let heading: String
  /// Said under the heading before the quote, such as that the lines have moved on.
  let caveat: String?
  let quote: [String]
  let text: String
}
