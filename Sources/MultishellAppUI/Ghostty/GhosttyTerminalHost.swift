import AppKit
import GhosttyTerminal
import MultishellAppCore
import MultishellCore

/// A `TerminalHost` backed by libghostty, which owns the pty, renderer and
/// config. Three config layers; see Docs/design/terminals.md.
@MainActor
final class GhosttyTerminalHost: NSObject, TerminalHost {
  /// A session's surface, the view the window holds it in, and its observer,
  /// held here because `TerminalView.delegate` is weak.
  private struct OpenSurface {
    let view: TerminalView
    let container: GhosttySurfaceContainer
    let observer: SurfaceObserver
  }

  weak var delegate: (any TerminalHostDelegate)?

  private let controllerOwner = GhosttyControllerOwner()
  private var surfaces: [TerminalSession.ID: OpenSurface] = [:]

  /// Clears what an earlier run left, before any controller writes its own.
  /// See Docs/design/terminals.md.
  func claimSharedFiles() {
    controllerOwner.claimSharedFiles()
  }

  func shutDown() {
    controllerOwner.shutDown()
  }

  /// `MULTISHELL_TERMINAL_DEBUG=1` makes libghostty's wrapper report what it
  /// hands the surface on stderr. No test can see the engine's own path.
  private static let debugLogging: Void = {
    guard ProcessInfo.processInfo.environment["MULTISHELL_TERMINAL_DEBUG"] != nil else { return }
    TerminalDebugLog.isEnabled = true
  }()

  var openSessionIDs: Set<TerminalSession.ID> { Set(surfaces.keys) }

  func open(_ session: TerminalSession) throws {
    _ = Self.debugLogging
    guard surfaces[session.id] == nil else { return }

    let view = TerminalView(frame: .zero)
    view.controller = controllerOwner.controller
    view.configuration = TerminalSurfaceOptions(
      backend: .exec,
      workingDirectory: session.workingDirectory.path,
      envVars: SessionEnvironment.variables(
        for: session, socket: Paths.socketFile, engineZshBootstrap: Self.zshBootstrap),
      command: Self.command(for: session)
    )

    let observer = SurfaceObserver(sessionID: session.id, host: self)
    view.delegate = observer
    surfaces[session.id] = OpenSurface(
      view: view, container: GhosttySurfaceContainer(surface: view), observer: observer)
  }

  /// libghostty's own zsh startup file, entered before ours so its marks and
  /// titles are written; see `ShellLaunch.zshEnvironment`.
  private static let zshBootstrap: URL? = GhosttyRuntimeResources.directoryURL?
    .appendingPathComponent("shell-integration/zsh", isDirectory: true)

  /// A tab's command, or an override naming a chosen shell. zsh as `$SHELL`
  /// needs none, its hooks riding in on `ZDOTDIR`.
  private static func command(for session: TerminalSession) -> String? {
    if let command = session.command { return PosixShellQuoting.commandLine(command) }
    return ShellLaunch.overrideCommand(forShell: session.shellPath).map(
      PosixShellQuoting.commandLine)
  }

  func close(_ id: TerminalSession.ID) {
    guard let surface = surfaces.removeValue(forKey: id) else { return }
    surface.container.removeFromSuperview()
    // Detaching the controller closes the pty rather than waiting on SwiftUI
    // to let the view go. Next turn: this runs inside a close callback.
    DispatchQueue.main.async { surface.view.controller = nil }
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    surfaces[id]?.container
  }

  /// libghostty frames this as a paste itself. `false` means the surface is
  /// not created yet, which a session with no shell running is.
  @discardableResult
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard !text.isEmpty, let view = surfaces[id]?.view else { return false }
    return view.paste(text: text)
  }

  func focus(_ id: TerminalSession.ID) {
    surfaces[id]?.view.takeFirstResponder()
  }

  func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool {
    guard let view = surfaces[id]?.view else { return false }
    var performed = true
    for action in GhosttySearchActions.actions(for: command) {
      performed = view.performBindingAction(action) && performed
    }
    return performed
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    controllerOwner.apply(theme, appearance: appearance)
  }

  fileprivate func surfaceRetitled(_ id: TerminalSession.ID, to title: String) {
    delegate?.terminalHost(self, didRetitle: id, to: title)
  }

  fileprivate func surfaceExited(_ id: TerminalSession.ID) {
    delegate?.terminalHost(self, didExit: id)
  }

  fileprivate func surfaceSawActivity(_ id: TerminalSession.ID) {
    delegate?.terminalHost(self, didSeeActivityIn: id)
  }

  fileprivate func surfaceFinishedCommand(_ id: TerminalSession.ID, exitCode: Int?) {
    delegate?.terminalHost(
      self, didFinishCommandIn: id, exitCode: exitCode.flatMap { Int32(exactly: $0) })
  }

  /// A turn later, and only while still true: a frame raises this inside
  /// SwiftUI's own update, where a store write is undefined behaviour.
  fileprivate func surfaceFocused(_ id: TerminalSession.ID) {
    Task { @MainActor [weak self] in
      guard let self, let view = surfaces[id]?.view, Self.hasKeyboard(view) else { return }
      delegate?.terminalHost(self, didFocus: id)
    }
  }

  /// libghostty may make an inner view the responder, so descendants count.
  private static func hasKeyboard(_ view: NSView) -> Bool {
    guard let responder = view.window?.firstResponder as? NSView else { return false }
    return responder === view || responder.isDescendant(of: view)
  }
}

extension GhosttyTerminalHost: TerminalSurfaceHost {}

/// libghostty's callbacks do not identify the surface that raised them, so one
/// observer is bound to each session.
@MainActor
private final class SurfaceObserver:
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
