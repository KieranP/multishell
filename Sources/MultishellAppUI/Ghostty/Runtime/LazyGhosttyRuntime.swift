import AppKit
import MultishellCore

/// The runtime every surface shares, built on first use with the user's
/// config under the app's layer; see Docs/design/terminals.md.
@MainActor
final class LazyGhosttyRuntime {
  private let readBase: @MainActor () -> String
  private var builtRuntime: GhosttyRuntime?
  /// Held until there is a runtime, so a theme at launch does not build one.
  private var latestAppLayer: (layer: GhosttyConfigText, isDark: Bool)?

  var runtime: GhosttyRuntime {
    if let builtRuntime { return builtRuntime }
    let made = GhosttyRuntime(
      readBase: readBase,
      appLayer: latestAppLayer?.layer ?? GhosttyConfigText(),
    )
    if let latestAppLayer { made.setColorScheme(isDark: latestAppLayer.isDark) }
    builtRuntime = made
    return made
  }

  init(readBase: @escaping @MainActor () -> String = { GhosttyUserConfig.base() }) {
    self.readBase = readBase
  }

  func apply(_ theme: Theme, appearance: Appearance) {
    let layer = GhosttyAppLayer.configuration(theme, appearance)
    latestAppLayer = (layer, theme.isDark)
    builtRuntime?.apply(appLayer: layer)
    builtRuntime?.setColorScheme(isDark: theme.isDark)
  }
}
