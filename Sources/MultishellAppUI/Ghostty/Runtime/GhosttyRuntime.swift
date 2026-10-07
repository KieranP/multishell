import AppKit
import GhosttyKit
import os

/// The one libghostty app every surface shares, and its config: the user's
/// base with the app's layer after it, so the app's colours, font and unbinds win.
@MainActor
final class GhosttyRuntime {
  let app: ghostty_app_t
  private let readBase: @MainActor () -> String
  private var base: String
  private var appLayer: GhosttyConfigText
  /// The merged text libghostty runs, `nil` for its defaults. It lags the two
  /// layers after a failed load, so the next apply tries again.
  private var runningText: String?
  let secureInput = GhosttySecureInput()
  private let ticker = GhosttyTicker()
  private let paneEvents = GhosttyPaneEventMonitor()
  private let configDirectory: URL
  private var observers: [any NSObjectProtocol] = []
  private static let logger = Logger(subsystem: MacPlatform.bundleIdentifier, category: "ghostty")

  /// Started from both layers in one load, or from libghostty's defaults where
  /// that load fails.
  init(
    readBase: @escaping @MainActor () -> String = { "" },
    appLayer: GhosttyConfigText = GhosttyConfigText(),
    configDirectory: URL = FileManager.default.temporaryDirectory
  ) {
    self.readBase = readBase
    let base = readBase()
    self.base = base
    self.appLayer = appLayer
    self.configDirectory = configDirectory
    let text = Self.mergedText(base: base, appLayer: appLayer)
    let loaded = Self.load(text, in: configDirectory)
    guard let config = loaded ?? GhosttyLoadedConfig.defaults() else {
      preconditionFailure("libghostty could not make a config")
    }
    var callbacks = GhosttyRuntimeCallbacks.runtimeConfig(waking: ticker.userdata)
    guard let app = ghostty_app_new(&callbacks, config.config) else {
      preconditionFailure("libghostty refused to start an app")
    }
    self.app = app
    runningText = loaded == nil ? nil : text
    followSecureInputSetting(of: config)
    ticker.runtime = self
    ghostty_app_set_focus(app, NSApp?.isActive ?? false)
    observeApplication()
  }

  isolated deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
    ghostty_app_free(app)
  }

  /// Applied as it is: libghostty skips a line it refuses and keeps the rest,
  /// as Ghostty does with a user's file.
  func apply(base newBase: String) {
    base = newBase
    reloadIfChanged()
  }

  func apply(appLayer newLayer: GhosttyConfigText) {
    appLayer = newLayer
    reloadIfChanged()
  }

  /// What a new surface answers a program asking if the terminal is dark,
  /// until its view's appearance says; the view sets its own from then.
  func setColorScheme(isDark: Bool) {
    ghostty_app_set_color_scheme(app, GhosttyColorScheme.scheme(isDark: isDark))
  }

  func tick() {
    ghostty_app_tick(app)
  }

  private func reloadIfChanged() {
    let text = Self.mergedText(base: base, appLayer: appLayer)
    guard text != runningText, let next = Self.load(text, in: configDirectory) else { return }
    ghostty_app_update_config(app, next.config)
    runningText = text
    followSecureInputSetting(of: next)
  }

  private func followSecureInputSetting(of config: GhosttyLoadedConfig) {
    secureInput.followsPasswordPrompts = config.flag("macos-auto-secure-input") ?? true
  }

  private static func mergedText(base: String, appLayer: GhosttyConfigText) -> String {
    [base, appLayer.rendered].filter { !$0.isEmpty }.joined(separator: "\n")
  }

  private static func load(_ text: String, in directory: URL) -> GhosttyLoadedConfig? {
    guard let loaded = GhosttyLoadedConfig.load(text, in: directory) else {
      logger.error(
        "libghostty made no config from text under \(directory.path, privacy: .public)")
      return nil
    }
    // Line numbers count in the merged text, not in the user's own file.
    for refused in loaded.diagnostics {
      logger.notice("libghostty refused a config line: \(refused, privacy: .public)")
    }
    return loaded
  }

  /// An edit to the user's file is made in another app, so switching back is
  /// when the base can have changed.
  private func applicationDidBecomeActive() {
    ghostty_app_set_focus(app, true)
    secureInput.applicationDidBecomeActive()
    apply(base: readBase())
  }

  private func applicationDidResignActive() {
    ghostty_app_set_focus(app, false)
    secureInput.applicationDidResignActive()
  }

  private func observeApplication() {
    let keyboard = NSTextInputContext.keyboardSelectionDidChangeNotification
    let changes: [(NSNotification.Name, @MainActor @Sendable (GhosttyRuntime) -> Void)] = [
      (NSApplication.didBecomeActiveNotification, { $0.applicationDidBecomeActive() }),
      (NSApplication.didResignActiveNotification, { $0.applicationDidResignActive() }),
      (keyboard, { ghostty_app_keyboard_changed($0.app) }),
    ]
    observers = NotificationCenter.default.observe(changes, for: self)
  }
}
