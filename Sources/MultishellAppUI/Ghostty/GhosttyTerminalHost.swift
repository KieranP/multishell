import AppKit
import MultishellAppCore
import MultishellCore

/// A `TerminalHost` backed by libghostty, which owns the pty, renderer and
/// config. Three config layers; see Docs/design/terminals.md.
@MainActor
final class GhosttyTerminalHost: NSObject, TerminalHost {
  weak var delegate: (any TerminalHostDelegate)?

  private let runtimeOwner = GhosttyRuntimeOwner()
  private var views: [TerminalSession.ID: GhosttySurfaceView] = [:]

  var liveSessionIDs: Set<TerminalSession.ID> { Set(views.keys) }

  func open(_ session: TerminalSession) throws {
    guard views[session.id] == nil else { return }
    let launch = GhosttySurfaceLaunch(
      workingDirectory: session.workingDirectory.path,
      environment: SessionEnvironment.variables(for: session, socket: Paths.socketFile),
      command: Self.command(for: session))
    let view = GhosttySurfaceView(runtime: runtimeOwner.runtime, launch: launch)
    guard view.surface != nil else { throw TerminalUnavailable() }
    connect(view, to: session.id)
    views[session.id] = view
  }

  /// A tab's command, or an override naming a chosen shell. zsh as `$SHELL`
  /// needs none, its hooks riding in on `ZDOTDIR`.
  static func command(for session: TerminalSession) -> String? {
    if let command = session.command { return PosixShellQuoting.commandLine(command) }
    return ShellLaunch.overrideCommand(forShell: session.shellPath).map(
      PosixShellQuoting.commandLine)
  }

  private func connect(_ view: GhosttySurfaceView, to id: TerminalSession.ID) {
    view.onRetitle = { [weak self] title in
      self.map { $0.delegate?.terminalHost($0, didRetitle: id, to: title) }
    }
    view.onBell = { [weak self] in
      self.map { $0.delegate?.terminalHost($0, didSeeActivityIn: id) }
    }
    view.onCommandFinish = { [weak self] exitCode in
      self.map {
        $0.delegate?.terminalHost(
          $0, didFinishCommandIn: id, exitCode: exitCode.flatMap { Int32(exactly: $0) })
      }
    }
    view.onExit = { [weak self] in self.map { $0.delegate?.terminalHost($0, didExit: id) } }
    view.onCloseRequest = { [weak self] in
      self.map { $0.delegate?.terminalHost($0, didAskToClose: id) }
    }
    view.onFocus = { [weak self] in self?.surfaceFocused(id) }
  }

  func close(_ id: TerminalSession.ID) {
    guard let view = views.removeValue(forKey: id) else { return }
    view.removeFromSuperview()
    // Next turn: this can run inside libghostty's own close callback.
    DispatchQueue.main.async { view.free() }
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    views[id]
  }

  func processHint(of id: TerminalSession.ID) -> TerminalProcessHint? {
    guard let view = views[id] else { return nil }
    return TerminalProcessHint(terminalPath: view.terminalPath, foregroundPID: view.foregroundPID)
  }

  /// libghostty frames this as a paste itself. `false` means there is no
  /// surface, which a session with no shell running has none of.
  @discardableResult
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard !text.isEmpty, let view = views[id] else { return false }
    return view.typeAsPaste(text)
  }

  func focus(_ id: TerminalSession.ID) {
    views[id]?.takeFirstResponder()
  }

  func search(_ command: TerminalSearch, in id: TerminalSession.ID) -> Bool {
    views[id]?.performBindingAction(GhosttySearchActions.action(for: command)) ?? false
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    runtimeOwner.apply(theme, appearance: appearance)
  }

  /// A turn later, and only while still true: a frame raises this inside
  /// SwiftUI's own update, where a store write is undefined behaviour.
  private func surfaceFocused(_ id: TerminalSession.ID) {
    Task { @MainActor [weak self] in
      guard let self, views[id]?.isFirstResponder == true else { return }
      delegate?.terminalHost(self, didFocus: id)
    }
  }
}

extension GhosttyTerminalHost: TerminalSurfaceHost {}
