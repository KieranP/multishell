import GhosttyTerminal
import MultishellCore

/// libghostty's callbacks do not identify the surface that raised them, so one
/// observer is bound to each session.
@MainActor
final class GhosttySurfaceObserver:
  TerminalSurfaceTitleDelegate,
  TerminalSurfaceCloseDelegate,
  TerminalSurfaceBellDelegate,
  TerminalSurfaceCommandFinishedDelegate,
  TerminalSurfaceFocusDelegate
{
  private let sessionID: TerminalSession.ID
  private weak var host: GhosttyTerminalHost?

  init(sessionID: TerminalSession.ID, host: GhosttyTerminalHost) {
    self.sessionID = sessionID
    self.host = host
  }

  func terminalDidChangeTitle(_ title: String) {
    host?.surfaceRetitled(sessionID, to: title)
  }

  func terminalDidClose(processAlive: Bool) {
    host?.surfaceExited(sessionID)
  }

  func terminalDidRingBell() {
    host?.surfaceSawActivity(sessionID)
  }

  /// Needs shell integration in the child shell, which zsh and bash get and
  /// fish and nu do not; see COMPAT.md.
  func terminalDidFinishCommand(exitCode: Int?, durationNanos: UInt64) {
    host?.surfaceFinishedCommand(sessionID, exitCode: exitCode)
  }

  func terminalDidChangeFocus(_ focused: Bool) {
    if focused { host?.surfaceFocused(sessionID) }
  }
}
