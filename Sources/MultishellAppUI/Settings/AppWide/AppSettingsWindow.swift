import SwiftUI

/// App-wide preferences, under Multishell > Settings. Help sits behind each
/// row's (i); captions are kept for values computed live.
struct AppSettingsWindow: View {
  let model: AppModel
  let platform: MacPlatform

  private enum Page: Hashable {
    case general, worktrees, terminal, agents, notifications, appearance
  }

  @State private var page = Page.general

  var body: some View {
    TabView(selection: $page) {
      AppGeneralPage(model: model)
        .tabItem { SettingsPageLabel.general.label }
        .tag(Page.general)
      AppWorktreesPage(model: model)
        .tabItem { SettingsPageLabel.worktrees.label }
        .tag(Page.worktrees)
      AppTerminalPage(model: model)
        .tabItem { SettingsPageLabel.terminal.label }
        .tag(Page.terminal)
      AppAgentsPage(model: model)
        .tabItem { SettingsPageLabel.agents.label }
        .tag(Page.agents)
      AppNotificationsPage(model: model)
        .tabItem { SettingsPageLabel.notifications.label }
        .tag(Page.notifications)
      AppAppearancePage(model: model)
        .tabItem { SettingsPageLabel.appearance.label }
        .tag(Page.appearance)
    }
    .settingsWindow(platform: platform, showFirstPage: { page = .general })
  }
}
