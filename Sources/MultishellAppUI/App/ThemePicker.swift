import MultishellAppCore
import MultishellCore
import SwiftUI

/// The theme choice the Terminal menu offers; Settings > Appearance shares its
/// binding in its own pop-up.
struct ThemePicker: View {
  let title: String
  let model: AppModel

  var body: some View {
    Picker(title, selection: model.themeBinding) {
      ForEach(model.themes) { Text($0.name).tag($0.id) }
    }
  }
}
