import Foundation

@MainActor
public protocol TerminalHostDelegate: AnyObject {
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String)
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID)
  /// Something happened the user may want to see. The engine cannot report
  /// "a command is running", so this is the honest signal for a dot.
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID)
  /// The user clicked into a surface. With splits, this is how the core
  /// learns which pane a split or close should act on.
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID)
  /// The shell's foreground command returned. Needs shell integration, which
  /// only Ghostty has; the one signal outranking an agent's own report.
  func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?)
}
