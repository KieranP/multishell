import AppKit
import MultishellCore
import SwiftTerm

/// A `TerminalHost` backed by SwiftTerm.
///
/// SwiftTerm owns the pty but hands us the view, so this type maps session ids
/// to views and forwards SwiftTerm's callbacks to the core's delegate.
@MainActor
final class SwiftTermTerminalHost: NSObject, TerminalHost {
  weak var delegate: (any TerminalHostDelegate)?

  private var views: [TerminalSession.ID: LocalProcessTerminalView] = [:]
  private var clickMonitor: Any?
  private var sessionIDs: [ObjectIdentifier: TerminalSession.ID] = [:]
  /// Sessions whose child has already exited. SwiftTerm keeps the pid after
  /// reaping it, so `terminate` would signal a number the kernel may have
  /// handed to some other process by now.
  private var exited: Set<TerminalSession.ID> = []
  /// How long a shell gets to act on SIGTERM before SIGKILL. Settable so a
  /// test does not wait the full time.
  var terminationGrace: Duration = .seconds(5)
  private var theme: Theme = .multishellDark
  private var appearance = Appearance()

  var openSessionIDs: Set<TerminalSession.ID> { Set(views.keys) }

  func open(_ session: TerminalSession) throws {
    guard views[session.id] == nil else { return }

    let view = LocalProcessTerminalView(frame: .zero)
    view.processDelegate = self
    style(view)
    installClickMonitorIfNeeded()

    views[session.id] = view
    sessionIDs[ObjectIdentifier(view)] = session.id

    let (executable, arguments) = Self.launch(session)
    view.startProcess(
      executable: executable,
      args: arguments,
      environment: Self.environment(for: session),
      execName: nil,
      currentDirectory: session.workingDirectory.path
    )
  }

  func close(_ id: TerminalSession.ID) {
    guard let view = views.removeValue(forKey: id) else { return }
    sessionIDs[ObjectIdentifier(view)] = nil
    // Removing the view does not end the child; SwiftTerm keeps the pty
    // until told otherwise.
    if exited.remove(id) == nil {
      let pid = view.process.shellPid
      view.terminate()
      Self.reap(pid, killAfter: terminationGrace)
    }
    view.removeFromSuperview()
  }

  /// SwiftTerm's `terminate` sends SIGTERM and then cancels the exit monitor
  /// that would have called `waitpid`, so every closed tab left a zombie
  /// until the app quit. Collect the child here, and kill it if it has not
  /// gone by the deadline; the pid stays the shell's until it is collected.
  nonisolated private static func reap(_ pid: pid_t, killAfter grace: Duration) {
    guard pid > 0 else { return }
    Task.detached(priority: .utility) {
      let deadline = ContinuousClock.now + grace
      var status: Int32 = 0
      while waitpid(pid, &status, WNOHANG) == 0 {
        if ContinuousClock.now > deadline { kill(pid, SIGKILL) }
        try? await Task.sleep(for: .milliseconds(50))
      }
    }
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    views[id]
  }

  /// SwiftTerm's own paste is not public, so the framing is done here: a
  /// program that asked for bracketed paste sees one paste rather than a run
  /// of keystrokes. A session whose child has gone is left alone; its view
  /// still holds a pty nobody reads.
  @discardableResult
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    guard !text.isEmpty, let view = views[id], !exited.contains(id) else { return false }
    let bracketed = view.terminal?.bracketedPasteMode == true
    view.send(txt: bracketed ? Self.pasteStart + text + Self.pasteEnd : text)
    return true
  }

  /// `CSI 200 ~` and `CSI 201 ~`, spelled out because SwiftTerm keeps its
  /// copies in mutable statics that strict concurrency will not read.
  private static let pasteStart = "\u{1b}[200~"
  private static let pasteEnd = "\u{1b}[201~"

  func focus(_ id: TerminalSession.ID) {
    views[id]?.takeFirstResponder()
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    self.theme = theme
    self.appearance = appearance
    views.values.forEach(style)
  }

  /// SwiftTerm has no focus callback and `becomeFirstResponder` is not
  /// overridable, so clicks are watched at the window level and mapped back
  /// to the surface they landed in.
  private func installClickMonitorIfNeeded() {
    guard clickMonitor == nil else { return }
    clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
      MainActor.assumeIsolated { self?.reportClick(event) }
      return event
    }
  }

  private func reportClick(_ event: NSEvent) {
    guard
      let window = event.window,
      let hit = window.contentView?.hitTest(event.locationInWindow)
    else { return }
    for (id, view) in views where hit === view || hit.isDescendant(of: view) {
      delegate?.terminalHost(self, didFocus: id)
      return
    }
  }

  private func style(_ view: LocalProcessTerminalView) {
    view.installColors(theme.ansiRGB.map(Self.color))
    view.nativeBackgroundColor = Self.nsColor(theme.backgroundRGB)
    view.nativeForegroundColor = Self.nsColor(theme.foregroundRGB)
    view.caretColor = Self.nsColor(theme.cursorRGB)
    view.selectedTextBackgroundColor = Self.nsColor(theme.selectionRGB)
    view.font = Self.font(appearance)
  }

  /// SwiftTerm's own defaults (TERM, LANG, HOME and friends) plus the
  /// session's identity, so a hook inside can name its tab.
  private static func environment(for session: TerminalSession) -> [String] {
    Terminal.getEnvironmentVariables()
      + SessionEnvironment.variables(for: session, socket: Paths.socketFile)
      .map { "\($0.key)=\($0.value)" }
  }

  /// `nil` command means the shell in force for the tab, launched so the
  /// command-status hooks are injected for this session.
  private static func launch(_ session: TerminalSession) -> (String, [String]) {
    if let command = session.command, let executable = command.first {
      return (executable, Array(command.dropFirst()))
    }
    return (session.shellPath, ShellLaunch.arguments(forShell: session.shellPath))
  }

  private static func font(_ appearance: Appearance) -> NSFont {
    let size = appearance.fontSize
    guard let name = appearance.fontName, let font = NSFont(name: name, size: size) else {
      return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    return font
  }

  /// SwiftTerm's `Color` is 16 bits per channel.
  private static func color(_ rgb: RGB) -> SwiftTerm.Color {
    SwiftTerm.Color(red8: UInt16(rgb.red), green8: UInt16(rgb.green), blue8: UInt16(rgb.blue))
  }

  private static func nsColor(_ rgb: RGB) -> NSColor {
    NSColor(
      srgbRed: CGFloat(rgb.red) / 255,
      green: CGFloat(rgb.green) / 255,
      blue: CGFloat(rgb.blue) / 255,
      alpha: 1
    )
  }
}

// SwiftTerm declares this protocol nonisolated but only ever calls it from the
// main thread, so each method asserts that rather than hopping and losing
// ordering against the store. `LocalProcessTerminalView` consumes the bell
// itself, so title changes are the only activity this engine can report.
extension SwiftTermTerminalHost: LocalProcessTerminalViewDelegate {
  nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
    MainActor.assumeIsolated {
      guard let id = sessionIDs[ObjectIdentifier(source)] else { return }
      delegate?.terminalHost(self, didRetitle: id, to: title)
    }
  }

  nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
    MainActor.assumeIsolated {
      guard let id = sessionIDs[ObjectIdentifier(source)] else { return }
      exited.insert(id)
      delegate?.terminalHost(self, didExit: id, code: Self.exitStatus(exitCode))
    }
  }

  /// SwiftTerm passes `waitpid`'s raw status on one of its paths, so an exit
  /// of 3 arrives as 768. A real exit code fits in a byte; a multiple of 256
  /// above that is the shifted form.
  static func exitStatus(_ reported: Int32?) -> Int32 {
    guard let reported else { return 0 }
    return reported > 255 && reported & 0xFF == 0 ? reported >> 8 : reported
  }

  nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

  nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
