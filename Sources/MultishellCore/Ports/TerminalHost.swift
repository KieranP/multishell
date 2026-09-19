import Foundation

/// The seam between the core and whatever draws a terminal. The engine owns
/// the child and a replacement need not, so nothing here exposes a descriptor.
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

  /// A step of the engine's own search over the session's scrollback.
  /// `false` where the engine has no such session, or no search at all.
  @discardableResult
  func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool

  /// Sessions the host currently has open. `SessionRegistry` reconciles
  /// against this rather than keeping its own copy.
  var openSessionIDs: Set<TerminalSession.ID> { get }

  var delegate: (any TerminalHostDelegate)? { get set }

  /// The app is quitting. An engine holding files or processes outside its
  /// sessions drops them here; one that holds nothing need not answer.
  func shutDown()

  /// This copy holds the instance socket, so files every copy of the build
  /// shares are its to clear. A copy that handed over never says it.
  func claimSharedFiles()
}

extension TerminalHost {
  /// An engine with no search: the bar's steps land nowhere rather than
  /// failing the host.
  public func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool { false }

  public func shutDown() {}

  public func claimSharedFiles() {}
}

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

extension TerminalHostDelegate {
  /// A host without the distinction reports a finished command as activity.
  public func terminalHost(
    _ host: any TerminalHost, didFinishCommandIn id: TerminalSession.ID, exitCode: Int32?
  ) {
    terminalHost(host, didSeeActivityIn: id)
  }
}
