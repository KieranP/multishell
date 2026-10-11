import Foundation
import MultishellCore

/// A `TerminalHost` whose sessions each have a view to put on screen, the
/// platform fixing `Surface` once. Layout is the caller's job.
@MainActor
public protocol TerminalSurfaceHost<Surface>: TerminalHost {
  associatedtype Surface
  func view(for id: TerminalSession.ID) -> Surface?

  /// `nil` for a session not open, or an engine that cannot say.
  func processHint(of id: TerminalSession.ID) -> TerminalProcessHint?

  /// Bytes the session's screen and scrollback hold inside the app's own
  /// process; `nil` for a session not open, or an engine that cannot say.
  func terminalMemory(of id: TerminalSession.ID) -> UInt64?

  /// The session's text: its screen, or with `includingScrollback` every line
  /// kept. `nil` for a session not open.
  func text(of id: TerminalSession.ID, includingScrollback: Bool) -> String?

  /// Where the session's view sits in its window, in points from the top left;
  /// `nil` for one not on screen.
  func frame(of id: TerminalSession.ID) -> CGRect?

  /// The session as last drawn, as a PNG; `nil` for one not on screen.
  func screenshot(of id: TerminalSession.ID) -> Data?
}
