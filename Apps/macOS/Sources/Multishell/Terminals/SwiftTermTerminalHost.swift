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
      environment: nil,
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
      view.terminate()
    }
    view.removeFromSuperview()
  }

  func view(for id: TerminalSession.ID) -> NSView? {
    views[id]
  }

  func focus(_ id: TerminalSession.ID) {
    guard let view = views[id], let window = view.window else { return }
    if window.firstResponder !== view {
      window.makeFirstResponder(view)
      NSApp.setWindowsNeedUpdate(true)
    }
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

  /// `nil` command means the user's login shell, which is what a new tab is.
  private static func launch(_ session: TerminalSession) -> (String, [String]) {
    if let command = session.command, let executable = command.first {
      return (executable, Array(command.dropFirst()))
    }
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    return (shell, ["-l"])
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
      delegate?.terminalHost(self, didExit: id, code: exitCode ?? 0)
    }
  }

  nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

  nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
