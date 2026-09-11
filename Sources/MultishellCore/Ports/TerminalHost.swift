import Foundation

/// The seam between the core and whatever draws a terminal. The engines
/// differ on who owns the child, so nothing here exposes a descriptor.
@MainActor
public protocol TerminalHost: AnyObject {
  func open(_ session: TerminalSession) throws
  func close(_ id: TerminalSession.ID)
  func focus(_ id: TerminalSession.ID)

  /// Text put into a session as if pasted, framed as one where the engine
  /// can. `false` when it reached no pty, so a drop is refused not swallowed.
  @discardableResult
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool

  /// Applied to every open terminal and to any opened afterwards.
  func apply(_ theme: Theme, appearance: Appearance)

  /// Sessions the host currently has open. `SessionRegistry` reconciles
  /// against this rather than keeping its own copy.
  var openSessionIDs: Set<TerminalSession.ID> { get }

  var delegate: (any TerminalHostDelegate)? { get set }
}

@MainActor
public protocol TerminalHostDelegate: AnyObject {
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String)
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32)
  /// Something happened the user may want to see. Neither engine reports "a
  /// command is running", so this is the honest signal for a dot.
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID)
  /// The user clicked into a surface. With splits, this is how the core
  /// learns which pane a split or close should act on.
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID)
  /// The shell's foreground command returned. Needs shell integration, which
  /// only Ghostty has; the one signal outranking an agent's own report.
  func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?)
}

extension TerminalHostDelegate {
  /// A host without the distinction reports a finished command as activity.
  public func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?
  ) {
    terminalHost(host, didSeeActivityIn: id)
  }
}
