import MultishellAppCore
import SwiftUI

/// What detection found, an agent, shell, editor or font, with Refresh where a
/// rescan of the PATH or the fonts can change it. `options(selected:)` keeps a stale choice.
struct DetectionMenu: View {
  let label: String
  @Binding var selection: String
  let options: (String) -> [DetectionOption]
  /// `nil` for a list the catalogue fixes, which no rescan changes.
  let refresh: (() -> Void)?

  var body: some View {
    let choices = options(selection)
    SettingsPopUp(
      label: label,
      selection: $selection,
      title: choices.label(of: selection) ?? selection,
    ) {
      ForEach(choices) { option in
        if option.id == DetectionOption.dividerID {
          Divider()
        } else {
          Text(option.label).tag(option.id)
        }
      }
    }
    if let refresh {
      SettingsSymbolButton.refresh(action: refresh)
    }
  }
}

// Beside the memberwise init, which stays synthesized.
// swiftlint:disable:next no_grouping_extension
extension DetectionMenu {
  /// Refresh reads the login shell again, whose PATH is where agents, shells
  /// and editors are found.
  static func refreshingLogin(of model: AppModel) -> () -> Void {
    { Task { await model.refreshLoginEnvironment() } }
  }
}
