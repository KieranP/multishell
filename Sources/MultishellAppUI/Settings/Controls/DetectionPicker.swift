import MultishellAppCore
import SwiftUI

/// A settings row holding a `DetectionMenu`: an agent, shell, editor, font or a
/// list the catalogue fixes.
struct DetectionPicker: View {
  let label: String
  @Binding var selection: String
  let options: (String) -> [DetectionOption]
  /// `nil` for a list the catalogue fixes, which no rescan changes.
  var refresh: (() -> Void)?
  let info: String
  /// Greys the control while it has nothing to choose; the (i) stays readable.
  var isEnabled = true

  var body: some View {
    InfoLabeledContent(label, info: info) {
      DetectionMenu(label: label, selection: $selection, options: options, refresh: refresh)
        .disabled(!isEnabled)
    }
  }
}

// Beside the memberwise init, which stays synthesized.
// swiftlint:disable:next no_grouping_extension
extension DetectionPicker {
  /// Refreshing reads the login shell again, whose PATH is where agents,
  /// shells and editors are found.
  init(
    label: String,
    selection: Binding<String>,
    options: @escaping (String) -> [DetectionOption],
    refreshing model: AppModel,
    info: String,
    isEnabled: Bool = true,
  ) {
    self.init(
      label: label,
      selection: selection,
      options: options,
      refresh: DetectionMenu.refreshingLogin(of: model),
      info: info,
      isEnabled: isEnabled,
    )
  }
}
