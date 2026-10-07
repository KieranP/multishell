import AppKit
import MultishellCore

/// The runtime every surface shares, built on first use with the user's
/// config under the app's layer; see Docs/design/terminals.md.
@MainActor
final class GhosttyRuntimeOwner {
  private let readBase: @MainActor () -> String
  private var built: GhosttyRuntime?
  /// Held until there is a runtime, so a theme at launch does not build one.
  private var latestAppLayer: (layer: GhosttyConfigText, isDark: Bool)?

  init(readBase: @escaping @MainActor () -> String = { GhosttyUserConfig.base() }) {
    self.readBase = readBase
  }

  var runtime: GhosttyRuntime {
    if let built { return built }
    let made = GhosttyRuntime(
      readBase: readBase, appLayer: latestAppLayer?.layer ?? GhosttyConfigText())
    if let latestAppLayer { made.setColorScheme(isDark: latestAppLayer.isDark) }
    built = made
    return made
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    let layer = GhosttyAppLayer.configuration(theme, appearance)
    latestAppLayer = (layer, theme.isDark)
    built?.apply(appLayer: layer)
    built?.setColorScheme(isDark: theme.isDark)
  }
}
