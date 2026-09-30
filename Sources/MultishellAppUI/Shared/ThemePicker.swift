import MultishellAppCore
import SwiftUI

/// The theme choice, offered by the View menu and Settings > Appearance alike.
struct ThemePicker: View {
  let title: String
  let model: AppModel

  var body: some View {
    Picker(title, selection: model.setting(\.appearance.themeID, write: model.setTheme)) {
      ForEach(model.themes) { Text($0.name).tag($0.id) }
    }
  }
}
