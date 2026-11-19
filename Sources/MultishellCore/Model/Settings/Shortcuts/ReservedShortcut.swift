/// A combination macOS or the app keeps over its windows, which no command
/// may take and the terminal surface gives up; Docs/design/shortcuts.md.
public enum ReservedShortcut: CaseIterable, Sendable {
  case accessibilityShortcuts
  case appSwitcher
  case appSwitcherBackwards
  case appWindows
  /// AppKit's Cancel, which closes a sheet or an alert and stops a field's edit.
  case cancel
  /// The WindowServer takes it before a menu bar sees it.
  case dockHiding
  /// Edit > Emoji & Symbols, which AppKit adds.
  case emojiAndSymbols
  case finderSearch
  case fullScreen
  /// The Help menu's search field, which AppKit adds.
  case helpSearch
  case hide
  case hideOthers
  case lockScreen
  case logOut
  case logOutNow
  case lookUp
  case minimize
  /// Window > Minimize All, the alternate AppKit shows with ⌥.
  case minimizeAll
  case missionControl
  /// On the system-owned list since the first build, for a reason not recorded.
  case newWindow
  case nextInputSource
  case previousInputSource
  case quit
  case screenshot
  case screenshotOfArea
  case screenshotOfAreaToClipboard
  case screenshotToClipboard
  case screenshotTools
  /// Sends a review comment from its composer.
  case send
  case settings
  /// View > Show All Tabs, which AppKit adds for window tabbing.
  case showAllTabs
  case spaceLeft
  case spaceRight
  case spotlight
  case voiceOver
  case windowCycling
  case windowCyclingBackwards

  public var combination: KeyCombination {
    switch self {
    case .quit: .command("q")
    case .hide: .command("h")
    case .hideOthers: .command("h", .option)
    case .minimize: .command("m")
    case .minimizeAll: .command("m", .option)
    case .voiceOver: KeyCombination(.function(5), .command)
    case .accessibilityShortcuts: KeyCombination(.function(5), [.option, .command])
    case .lookUp: .command("d", .control)
    case .settings: .command(",")
    case .dockHiding: .command("d", .option)
    case .fullScreen: .command("f", .control)
    case .appSwitcher: KeyCombination(.tab, .command)
    case .cancel: .command(".")
    case .appSwitcherBackwards: KeyCombination(.tab, [.shift, .command])
    case .spotlight: KeyCombination(.space, .command)
    case .windowCycling: .command("`")
    case .windowCyclingBackwards: .command("`", .shift)
    case .newWindow: .command("n", .shift)
    case .send: KeyCombination(.returnKey, .command)
    case .lockScreen: .command("q", .control)
    case .logOut: .command("q", .shift)
    case .logOutNow: .command("q", [.option, .shift])
    case .screenshot: .command("3", .shift)
    case .screenshotOfArea: .command("4", .shift)
    case .screenshotTools: .command("5", .shift)
    case .screenshotToClipboard: .command("3", [.control, .shift])
    case .screenshotOfAreaToClipboard: .command("4", [.control, .shift])
    case .spaceLeft: KeyCombination(.leftArrow, .control)
    case .spaceRight: KeyCombination(.rightArrow, .control)
    case .missionControl: KeyCombination(.upArrow, .control)
    case .appWindows: KeyCombination(.downArrow, .control)
    case .finderSearch: KeyCombination(.space, [.option, .command])
    case .previousInputSource: KeyCombination(.space, .control)
    case .nextInputSource: KeyCombination(.space, [.control, .option])
    case .emojiAndSymbols: KeyCombination(.space, [.control, .command])
    case .helpSearch: .command("/", .shift)
    case .showAllTabs: .command("\\", .shift)
    }
  }

  static func holding(_ combination: KeyCombination) -> Self? {
    allCases.first { $0.combination == combination }
  }
}
