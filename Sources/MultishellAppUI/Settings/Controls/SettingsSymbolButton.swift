import SwiftUI

/// A one-symbol button for the settings windows, a word beside a dropdown
/// pushing rows onto two lines. One symbol and help per meaning.
struct SettingsSymbolButton: View {
  let symbol: String
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
    }
    .buttonStyle(.borderless)
    .help(help)
    .accessibilityLabel(help)
  }

  static func refresh(
    help: String = t("action.refresh"),
    action: @escaping () -> Void,
  )
    -> Self
  {
    Self(symbol: "arrow.clockwise", help: help, action: action)
  }

  /// A project's override handing the setting back to the value it followed.
  static func useGlobal(action: @escaping () -> Void) -> Self {
    Self(symbol: "arrow.uturn.backward", help: t("project.use-global"), action: action)
  }

  static func reveal(action: @escaping () -> Void) -> Self {
    Self(
      symbol: "magnifyingglass",
      help: t("action.reveal-in-finder"),
      action: action,
    )
  }
}
