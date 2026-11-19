/// The end of a failed check's log, as much as was asked for, and how many lines
/// of the whole log came before it.
public struct FailedCheckLog: Equatable, Sendable {
  public let text: String
  public let earlierLineCount: Int
}
