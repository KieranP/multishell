import AppKit
import MultishellCore

/// The runtime every surface shares, built on first use with the user's
/// config under the app's layer; see Docs/design/terminals.md.
@MainActor
final class GhosttyRuntimeOwner {
  private var built: GhosttyRuntime?
  /// Held until there is a runtime, so a theme at launch does not build one.
  private var latestAppLayer: (layer: GhosttyConfigText, isDark: Bool)?
  private var activationObservers: [any NSObjectProtocol] = []

  var runtime: GhosttyRuntime {
    if let built { return built }
    let made = GhosttyRuntime(
      base: GhosttyUserConfig.base(), appLayer: latestAppLayer?.layer ?? GhosttyConfigText())
    if let latestAppLayer { made.setColorScheme(dark: latestAppLayer.isDark) }
    built = made
    // An edit to the user's file is made in another app, so switching back
    // is when it can have changed.
    let reload: @MainActor @Sendable (GhosttyRuntimeOwner) -> Void = { $0.reloadUserConfig() }
    activationObservers = NotificationCenter.default.observe(
      [(NSApplication.didBecomeActiveNotification, reload)], for: self)
    return made
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    let layer = GhosttyAppLayer.configuration(theme, appearance)
    latestAppLayer = (layer, theme.isDark)
    built?.apply(appLayer: layer)
    built?.setColorScheme(dark: theme.isDark)
  }

  /// Read again, the runtime passing on only a change.
  private func reloadUserConfig() {
    built?.apply(base: GhosttyUserConfig.base())
  }
}
