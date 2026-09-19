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
    InfoRow(label, info: info) {
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
