import MultishellCore

extension ReservedShortcut {
  /// What the keys do now, as a refusal names it: "⌘Q is Quit Multishell".
  var use: String {
    switch self {
    case .quit: t("shortcuts.reserved-quit")
    case .hide: t("shortcuts.reserved-hide")
    case .hideOthers: t("shortcuts.reserved-hide-others")
    case .minimize: t("shortcuts.reserved-minimize")
    case .minimizeAll: t("shortcuts.reserved-minimize-all")
    case .voiceOver: t("shortcuts.reserved-voice-over")
    case .accessibilityShortcuts: t("shortcuts.reserved-accessibility-shortcuts")
    case .lookUp: t("shortcuts.reserved-look-up")
    case .settings: t("shortcuts.reserved-settings")
    case .dockHiding: t("shortcuts.reserved-dock-hiding")
    case .fullScreen: t("shortcuts.reserved-full-screen")
    case .appSwitcher: t("shortcuts.reserved-app-switcher")
    case .cancel: t("shortcuts.reserved-cancel")
    case .appSwitcherBackwards: t("shortcuts.reserved-app-switcher-backwards")
    case .spotlight: t("shortcuts.reserved-spotlight")
    case .windowCycling: t("shortcuts.reserved-window-cycling")
    case .windowCyclingBackwards: t("shortcuts.reserved-window-cycling-backwards")
    case .newWindow: t("shortcuts.reserved-new-window")
    case .send: t("shortcuts.reserved-send")
    case .lockScreen: t("shortcuts.reserved-lock-screen")
    case .logOut: t("shortcuts.reserved-log-out")
    case .logOutNow: t("shortcuts.reserved-log-out-now")
    case .screenshot: t("shortcuts.reserved-screenshot")
    case .screenshotOfArea: t("shortcuts.reserved-screenshot-of-area")
    case .screenshotTools: t("shortcuts.reserved-screenshot-tools")
    case .screenshotToClipboard: t("shortcuts.reserved-screenshot-to-clipboard")
    case .screenshotOfAreaToClipboard: t("shortcuts.reserved-screenshot-of-area-to-clipboard")
    case .spaceLeft: t("shortcuts.reserved-space-left")
    case .spaceRight: t("shortcuts.reserved-space-right")
    case .missionControl: t("shortcuts.reserved-mission-control")
    case .appWindows: t("shortcuts.reserved-app-windows")
    case .finderSearch: t("shortcuts.reserved-finder-search")
    case .previousInputSource: t("shortcuts.reserved-previous-input-source")
    case .nextInputSource: t("shortcuts.reserved-next-input-source")
    case .emojiAndSymbols: t("shortcuts.reserved-emoji-and-symbols")
    case .helpSearch: t("shortcuts.reserved-help-search")
    case .showAllTabs: t("shortcuts.reserved-show-all-tabs")
    }
  }
}
