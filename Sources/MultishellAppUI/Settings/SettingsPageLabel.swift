import SwiftUI

/// A settings page's title and toolbar symbol, one definition for the pages
/// both settings windows have.
struct SettingsPageLabel {
  static var general: Self { Self(title: t("settings.general"), symbol: "gearshape") }
  static var worktrees: Self {
    Self(title: t("settings.worktrees"), symbol: "arrow.trianglehead.branch")
  }
  static var hooks: Self { Self(title: t("settings.hooks"), symbol: "bolt.horizontal") }
  static var terminal: Self { Self(title: t("settings.terminal"), symbol: "terminal") }
  static var agents: Self { Self(title: t("label.agents"), symbol: "sparkles") }
  static var notifications: Self { Self(title: t("settings.notifications"), symbol: "bell") }
  static var appearance: Self { Self(title: t("settings.appearance"), symbol: "paintpalette") }

  let title: String
  let symbol: String

  var label: some View { Label(title, systemImage: symbol) }
}
