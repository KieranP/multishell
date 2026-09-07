import MultishellAppCore
import SwiftUI

/// App-wide preferences, under Multishell > Settings (Cmd+,).
/// Per-project settings live behind the cog on each sidebar row. Help sits
/// behind each row's (i); captions are kept for values computed live.
struct SettingsView: View {
  let model: AppModel

  var body: some View {
    TabView {
      GeneralSettingsTab(model: model)
        .tabItem { Label("General", systemImage: "gearshape") }
      WorktreeSettingsTab(model: model)
        .tabItem { Label("Worktrees", systemImage: "arrow.trianglehead.branch") }
      TerminalSettingsTab(model: model)
        .tabItem { Label("Terminal", systemImage: "terminal") }
      AgentSettingsTab(model: model)
        .tabItem { Label("Agents", systemImage: "sparkles") }
      AppearanceSettingsTab(model: model)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
    }
    .frame(width: 560, height: 480)
  }
}
