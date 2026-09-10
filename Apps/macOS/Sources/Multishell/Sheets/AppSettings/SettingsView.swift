import MultishellAppCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings (Cmd+,).
/// Per-project settings live behind the cog on each sidebar row. Help sits
/// behind each row's (i); captions are kept for values computed live.
struct SettingsView: View {
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
    .frame(width: 560, height: 480)
    .settingsWindowReset(
      on: { platform.mainWindow?.screen }, showFirstTab: { tab = .general })
  }
}
