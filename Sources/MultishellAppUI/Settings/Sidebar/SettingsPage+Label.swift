import MultishellAppCore
import SwiftUI

extension SettingsPage {
  var title: String {
    switch self {
    case .agents: t("label.agents")
    case .appearance: t("settings.appearance")
    case .general: t("settings.general")
    case .hooks: t("settings.hooks")
    case .integrations: t("settings.integrations")
    case .notifications: t("settings.notifications")
    case .terminal: t("settings.terminal")
    case .worktrees: t("settings.worktrees")
    }
  }

  /// The tile behind the glyph, each page its own as System Settings colours them.
  var tileColor: Color {
    switch self {
    case .agents: Color(red: 0.545, green: 0.361, blue: 0.965)
    case .appearance: Color(red: 0.039, green: 0.518, blue: 1)
    case .general: Color(red: 0.557, green: 0.557, blue: 0.576)
    case .hooks: Color(red: 0.878, green: 0.659, blue: 0)
    case .integrations: Color(red: 0.078, green: 0.639, blue: 0.639)
    case .notifications: Color(red: 1, green: 0.231, blue: 0.188)
    case .terminal: Color(red: 0.227, green: 0.227, blue: 0.235)
    case .worktrees: Color(red: 0.941, green: 0.541, blue: 0.141)
    }
  }
}
