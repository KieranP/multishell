/// The engine could not start a terminal for a session, its renderer or pty
/// refused, so `open` throws rather than keep a pane with nothing in it.
public struct TerminalUnavailable: Error, CustomStringConvertible {
  public init() {}

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "the terminal engine could not start a terminal" }
}
