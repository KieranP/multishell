import MultishellAppCore
import MultishellCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings. Help sits behind each
/// row's (i); captions are kept for values computed live.
struct SettingsView: View {
  /// Fixed, or the window would resize as the user moved between tabs. 600
  /// is the tallest page plus slack; SettingsPageSizeTests holds it.
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
        .tabItem { Label(t("settings.general"), systemImage: "gearshape") }
        .tag(Tab.general)
      WorktreeSettingsTab(model: model)
        .tabItem { Label(t("settings.worktrees"), systemImage: "arrow.trianglehead.branch") }
        .tag(Tab.worktrees)
      TerminalSettingsTab(model: model)
        .tabItem { Label(t("settings.terminal"), systemImage: "terminal") }
        .tag(Tab.terminal)
      AgentSettingsTab(model: model)
        .tabItem { Label(t("label.agents"), systemImage: "sparkles") }
        .tag(Tab.agents)
      NotificationSettingsTab(model: model)
        .tabItem { Label(t("settings.notifications"), systemImage: "bell") }
        .tag(Tab.notifications)
      AppearanceSettingsTab(model: model)
        .tabItem { Label(t("settings.appearance"), systemImage: "paintpalette") }
        .tag(Tab.appearance)
    }
    .frame(width: Self.windowSize.width, height: Self.windowSize.height)
    .settingsWindowReset(
      on: { platform.mainWindow?.screen }, showFirstTab: { tab = .general })
  }
}
