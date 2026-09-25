import AppKit
import GhosttyTerminal
import MultishellCore

/// The one libghostty controller every surface shares, built on first use,
/// with its config layers and the generated files; see Docs/design/terminals.md.
@MainActor
final class GhosttyControllerOwner {
  private var cachedController: TerminalController?
  private var pendingTheme: TerminalTheme?
  /// What the controller was last handed from the user's files, so coming to
  /// the front rereads them and pushes only a change.
  private var lastUserConfig = ""
  private var activationObserver: (any NSObjectProtocol)?
  /// The generated configs sit in a directory every copy of the build shares,
  /// so a copy that handed over would sweep a running copy's file with its own.
  private var ownsSharedFiles = false

  var controller: TerminalController {
    if let cachedController { return cachedController }
    let base = GhosttyUserConfig.base()
    let made = TerminalController(configSource: .generated(base))
    GhosttyUserConfig.repair(made, base: base)
    cachedController = made
    lastUserConfig = base
    if let pendingTheme { _ = made.setTheme(pendingTheme) }
    // An edit to the user's file is made in another app, so switching back
    // is when it can have changed.
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reloadUserConfig() }
    }
    return made
  }

  /// Clears what an earlier run left, before any controller writes its own.
  func claimSharedFiles() {
    ownsSharedFiles = true
    Self.removeGeneratedConfigs()
  }

  func shutDown() {
    guard ownsSharedFiles else { return }
    Self.removeGeneratedConfigs()
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    let configuration = GhosttyAppLayer.configuration(theme, appearance)
    // Both slots get the same config: the user picked a theme, so the
    // terminal should not flip with the system appearance.
    let applied = TerminalTheme(light: configuration, dark: configuration)
    pendingTheme = applied
    // Held rather than pushed where there is no controller yet, so a theme
    // at launch does not build one before the socket is claimed.
    guard let cachedController else { return }
    _ = cachedController.setTheme(applied)
  }

  private func reloadUserConfig() {
    guard let cachedController else { return }
    lastUserConfig = GhosttyUserConfig.reload(cachedController, over: lastUserConfig)
  }

  private static func removeGeneratedConfigs() {
    try? FileManager.default.removeItem(at: TerminalController.managedConfigDirectory)
  }
}
