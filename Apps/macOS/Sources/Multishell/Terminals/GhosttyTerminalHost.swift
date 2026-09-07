import AppKit
import GhosttyTerminal
import MultishellCore

/// A `TerminalHost` backed by libghostty.
///
/// libghostty owns the pty, the renderer and the config, so this type is
/// thin: it creates surfaces, routes their callbacks back to the core, and
/// translates a `Theme` into ghostty config.
@MainActor
final class GhosttyTerminalHost: NSObject, TerminalHost {
  weak var delegate: (any TerminalHostDelegate)?

  private let controller = TerminalController()
  private var surfaces: [TerminalSession.ID: TerminalView] = [:]
  private var containers: [TerminalSession.ID: SurfaceContainerView] = [:]
  /// `TerminalView.delegate` is weak, so the per-surface observers must be
  /// held here or callbacks stop arriving.
  private var observers: [TerminalSession.ID: SurfaceObserver] = [:]

  var openSessionIDs: Set<TerminalSession.ID> { Set(surfaces.keys) }

  func open(_ session: TerminalSession) throws {
    guard surfaces[session.id] == nil else { return }

    let view = TerminalView(frame: .zero)
    view.controller = controller
    view.configuration = TerminalSurfaceOptions(
      backend: .exec,
      workingDirectory: session.workingDirectory.path,
      envVars: SessionEnvironment.variables(for: session, socket: Paths.socketFile),
      command: Self.command(for: session)
    )

    let observer = SurfaceObserver(sessionID: session.id, host: self)
    view.delegate = observer
    observers[session.id] = observer

    let container = SurfaceContainerView(surface: view)
    surfaces[session.id] = view
    containers[session.id] = container
  }

  /// A tab's command, or an override that names a chosen shell or injects
  /// the hooks into an otherwise-default one. zsh as `$SHELL` needs none: its
  /// hooks ride in on `ZDOTDIR` from the environment, so its command stays
  /// the engine default (`nil`).
  private static func command(for session: TerminalSession) -> String? {
    if let command = session.command { return ShellQuoting.commandLine(command) }
    return ShellLaunch.overrideCommand(forShell: session.shellPath).map(ShellQuoting.commandLine)
  }

  func close(_ id: TerminalSession.ID) {
    observers[id] = nil
    containers.removeValue(forKey: id)?.removeFromSuperview()
    // Detaching the controller tears the surface down, which closes the pty
    // and ends the shell. The view's deallocation would do the same, but only
    // once every SwiftUI frame that adopted it has let go, and a shell is not
    // something to leave running on a layout detail. Next turn, not now: on
    // a process exit this runs inside libghostty's own close callback, and
    // freeing the surface there would free the object mid-call.
    guard let view = surfaces.removeValue(forKey: id) else { return }
    DispatchQueue.main.async { view.controller = nil }
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    containers[id]
  }

  /// libghostty frames this as a paste itself, bracketed where the program
  /// asked for it. `false` back means the surface is not created yet, which
  /// a session with no shell running is.
  @discardableResult
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard !text.isEmpty, let view = surfaces[id] else { return false }
    return view.paste(text: text)
  }

  func focus(_ id: TerminalSession.ID) {
    guard let view = surfaces[id], let window = view.window else { return }
    if window.firstResponder !== view {
      window.makeFirstResponder(view)
      // Menu enablement follows the first responder; ask AppKit to look
      // again now rather than at its next scheduled update.
      NSApp.setWindowsNeedUpdate(true)
    }
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    let configuration = Self.configuration(theme, appearance)
    // Both slots get the same config: the user picked a theme, so the
    // terminal should not flip with the system appearance.
    _ = controller.setTheme(TerminalTheme(light: configuration, dark: configuration))
  }

  private static func configuration(
    _ theme: Theme, _ appearance: Appearance
  ) -> TerminalConfiguration {
    TerminalConfiguration { builder in
      builder.withBackground(theme.background)
      builder.withForeground(theme.foreground)
      builder.withCursorColor(theme.cursor)
      builder.withSelectionBackground(theme.selectionBackground)
      for (index, colour) in theme.ansi.enumerated() {
        builder.withPalette(index, color: colour)
      }
      if let name = appearance.fontName {
        builder.withFontFamily(name)
      }
      builder.withFontSize(Float(appearance.fontSize))
      builder.withWindowPaddingX(8)
      builder.withWindowPaddingY(6)

      // Ghostty's defaults bind the app's shortcuts (super+t, super+w,
      // super+d, ctrl+tab, ...) to actions this embedding cannot
      // perform, and the surface consumes the keystroke before the menu
      // bar sees it. Unbind exactly those. `clear` would also drop the
      // bindings that make a Mac terminal feel right: alt+arrow word
      // movement, super+backspace, super+left/right.
      for combo in Self.appShortcuts {
        builder.withCustom("keybind", "\(combo)=unbind")
      }
    }
  }

  private static let appShortcuts: [String] =
    [
      "super+t", "super+shift+t", "super+alt+t", "super+w", "super+shift+w", "super+n",
      "super+shift+n",
      "super+o", "super+shift+o", "super+d", "super+shift+d", "super+comma", "super+q",
      "ctrl+tab", "ctrl+shift+tab",
      "super+ctrl+f", "super+enter",
    ]

  fileprivate func retitle(_ id: TerminalSession.ID, to title: String) {
    delegate?.terminalHost(self, didRetitle: id, to: title)
  }

  fileprivate func surfaceClosed(_ id: TerminalSession.ID) {
    delegate?.terminalHost(self, didExit: id, code: 0)
  }

  fileprivate func activity(in id: TerminalSession.ID) {
    delegate?.terminalHost(self, didSeeActivityIn: id)
  }

  fileprivate func commandFinished(in id: TerminalSession.ID, exitCode: Int?) {
    delegate?.terminalHost(
      self, didFinishCommandIn: id, exitCode: exitCode.flatMap { Int32(exactly: $0) })
  }

  fileprivate func focused(_ id: TerminalSession.ID) {
    delegate?.terminalHost(self, didFocus: id)
  }
}

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
    host?.retitle(sessionID, to: title)
  }

  func terminalDidClose(processAlive: Bool) {
    host?.surfaceClosed(sessionID)
  }

  func terminalDidRingBell() {
    host?.activity(in: sessionID)
  }

  /// Needs shell integration in the child shell; Ghostty's resources
  /// include it for zsh, bash and fish.
  func terminalDidFinishCommand(exitCode: Int?, durationNanos: UInt64) {
    host?.commandFinished(in: sessionID, exitCode: exitCode)
  }

  func terminalDidChangeFocus(_ focused: Bool) {
    if focused { host?.focused(sessionID) }
  }
}

/// Metal-backed surfaces need an explicit `fitToSize` after any layout change.
@MainActor
final class SurfaceContainerView: NSView {
  private let surface: TerminalView

  init(surface: TerminalView) {
    self.surface = surface
    super.init(frame: .zero)
    surface.autoresizingMask = [.width, .height]
    addSubview(surface)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    surface.frame = bounds
    surface.fitToSize()
  }

  /// A click anywhere in the container is a click on the terminal. Without
  /// this, a click that lands on the SwiftUI hosting layer leaves focus there
  /// and the Edit menu stays disabled until some later update moves it.
  override func mouseDown(with event: NSEvent) {
    if window?.firstResponder !== surface {
      window?.makeFirstResponder(surface)
    }
    super.mouseDown(with: event)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    surface.setSurfaceVisible(window != nil)
  }
}
