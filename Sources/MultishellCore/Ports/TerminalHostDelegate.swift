import Foundation

@MainActor
public protocol TerminalHostDelegate: AnyObject {
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String)
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID)
  /// The engine was asked to close a session whose process still runs, as by a
  /// keybind of the user's; the app's own close decides whether to ask first.
  func terminalHost(_ host: any TerminalHost, didAskToClose id: TerminalSession.ID)
  /// A link clicked in a session named a text file, which the editor the user
  /// chose opens rather than the engine.
  func terminalHost(_ host: any TerminalHost, didAskToEdit file: URL, in id: TerminalSession.ID)
  /// Something happened the user may want to see. The engine cannot report
  /// "a command is running", so this is the honest signal for a dot.
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID)
  /// The user clicked into a surface. With splits, this is how the core
  /// learns which pane a split or close should act on.
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID)
  /// The shell's foreground command returned. Needs shell integration, which
  /// only Ghostty has; the one signal outranking an agent's own report.
  func terminalHost(
    _ host: any TerminalHost,
    didFinishCommandIn id: TerminalSession.ID,
    exitCode: Int32?,
  )
  /// The engine's search counted its matches, or which one it is on.
  func terminalHost(
    _ host: any TerminalHost,
    didCount count: TerminalSearchCount,
    in id: TerminalSession.ID,
  )
}

extension TerminalHostDelegate {
  /// A host without the distinction reports a finished command as activity.
  public func terminalHost(
    _ host: any TerminalHost,
    didFinishCommandIn id: TerminalSession.ID,
    exitCode: Int32?,
  ) {
    terminalHost(host, didSeeActivityIn: id)
  }

  /// A delegate with no find bar has no use for a count.
  public func terminalHost(
    _ host: any TerminalHost,
    didCount count: TerminalSearchCount,
    in id: TerminalSession.ID,
  ) {}
}
