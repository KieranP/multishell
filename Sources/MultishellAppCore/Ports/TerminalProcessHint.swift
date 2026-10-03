/// What an engine knows of the process behind a session, by which the debug
/// panel finds a tab's processes. Either may be unknown.
public struct TerminalProcessHint: Sendable, Equatable {
  /// The pty's path, as `/dev/ttys004`.
  public let terminalPath: String?
  /// The pty's foreground process group: the program running, else the shell.
  public let foregroundPID: Int32?

  public init(terminalPath: String?, foregroundPID: Int32?) {
    self.terminalPath = terminalPath
    self.foregroundPID = foregroundPID
  }
}
