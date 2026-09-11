import MultishellAppCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings (Cmd+,).
/// Per-project settings live behind the cog on each sidebar row. Help sits
/// behind each row's (i); captions are kept for values computed live.
struct SettingsView: View {
  /// Fixed: a settings window sized to its tallest tab would resize as the
  /// user moved between them. So it is the tallest page's height and every
  /// shorter page carries the empty space, which at 159pt for General is
  /// most of the window. 600 is Project General's 581.5 with room for the
  /// couple of points a measurement moves between machines;
  /// SettingsPageSizeTests holds every page to it.
  static let windowSize = CGSize(width: 560, height: 600)

  let model: AppModel
  let platform: MacPlatform

  private enum Tab: Hashable {
    case general, worktrees, terminal, agents, notifications, appearance
  }

  @State private var tab = Tab.general

  var body: some View {
    TabView(selection: $tab) {
      GeneralSettingsTab(model: model)
        .tabItem { Label("General", systemImage: "gearshape") }
        .tag(Tab.general)
      WorktreeSettingsTab(model: model)
        .tabItem { Label("Worktrees", systemImage: "arrow.trianglehead.branch") }
        .tag(Tab.worktrees)
      TerminalSettingsTab(model: model)
        .tabItem { Label("Terminal", systemImage: "terminal") }
        .tag(Tab.terminal)
      AgentSettingsTab(model: model)
        .tabItem { Label("Agents", systemImage: "sparkles") }
        .tag(Tab.agents)
      NotificationSettingsTab(model: model)
        .tabItem { Label("Notifications", systemImage: "bell") }
        .tag(Tab.notifications)
      AppearanceSettingsTab(model: model)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
        .tag(Tab.appearance)
    }
    .frame(width: Self.windowSize.width, height: Self.windowSize.height)
    .settingsWindowReset(
      on: { platform.mainWindow?.screen }, showFirstTab: { tab = .general })
  }
}
