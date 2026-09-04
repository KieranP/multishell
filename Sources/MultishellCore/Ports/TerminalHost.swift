import Foundation

/// The seam between the core and whatever actually draws a terminal.
///
/// The core decides which sessions should exist; a host owns the pty and the
/// view. SwiftTerm and libghostty differ in who owns the child process, so
/// nothing here exposes a file descriptor or a byte stream.
@MainActor
public protocol TerminalHost: AnyObject {
  func open(_ session: TerminalSession) throws
  func close(_ id: TerminalSession.ID)
  func focus(_ id: TerminalSession.ID)

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
  /// Something happened the user may want to see: a bell, a finished
  /// command, a title change. Neither engine reports "a command is running",
  /// so this is the honest signal for an attention dot on a background tab.
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID)
  /// The user clicked into a surface. With splits, this is how the core
  /// learns which pane a split or close should act on.
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID)
}
