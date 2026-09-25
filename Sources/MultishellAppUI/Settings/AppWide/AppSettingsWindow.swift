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
      GeneralSettingsPage(model: model)
        .tabItem { Label(t("settings.general"), systemImage: "gearshape") }
        .tag(Page.general)
      WorktreesSettingsPage(model: model)
        .tabItem { Label(t("settings.worktrees"), systemImage: "arrow.trianglehead.branch") }
        .tag(Page.worktrees)
      TerminalSettingsPage(model: model)
        .tabItem { Label(t("settings.terminal"), systemImage: "terminal") }
        .tag(Page.terminal)
      AgentsSettingsPage(model: model)
        .tabItem { Label(t("label.agents"), systemImage: "sparkles") }
        .tag(Page.agents)
      NotificationsSettingsPage(model: model)
        .tabItem { Label(t("settings.notifications"), systemImage: "bell") }
        .tag(Page.notifications)
      AppearanceSettingsPage(model: model)
        .tabItem { Label(t("settings.appearance"), systemImage: "paintpalette") }
        .tag(Page.appearance)
    }
    .frame(width: SettingsWindow.size.width, height: SettingsWindow.size.height)
    .settingsWindowReset(
      on: { platform.mainWindow?.screen }, showFirstPage: { page = .general })
  }
}
