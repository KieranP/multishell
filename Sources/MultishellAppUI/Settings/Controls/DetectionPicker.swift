import MultishellAppCore
import SwiftUI

/// The dropdown both settings windows use for an agent, shell or editor.
/// `options(selected:)` keeps a stale choice listed rather than blank.
struct DetectionPicker: View {
  let label: String
  @Binding var selection: String
  let options: (String) -> [DetectionOption]
  let refresh: () -> Void
  let info: String
  /// Greys the control while an override is off; the (i) stays readable.
  var isEnabled = true

  var body: some View {
    InfoLabeledContent(label, info: info) {
      Picker(label, selection: $selection) {
        ForEach(options(selection)) { option in
          if option.id == FontDetection.dividerID {
            Divider()
          } else {
            Text(option.label).tag(option.id)
          }
        }
      }
      .disabled(!isEnabled)
      IconButton.refresh(action: refresh).controlSize(.small).disabled(!isEnabled)
    }
  }
}

extension DetectionPicker {
  /// Refreshing reads the login shell again, whose PATH is where agents,
  /// shells and editors are found.
  init(
    label: String, selection: Binding<String>, options: @escaping (String) -> [DetectionOption],
    rescanning model: AppModel, info: String, isEnabled: Bool = true
  ) {
    self.init(
      label: label, selection: selection, options: options,
      refresh: { Task { await model.refreshLoginEnvironment() } }, info: info,
      isEnabled: isEnabled)
  }
}
