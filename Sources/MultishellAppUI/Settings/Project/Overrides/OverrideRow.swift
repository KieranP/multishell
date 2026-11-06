import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project's settings table row: the setting, the value it follows, and its own
/// value or the button to start one. One key path, so it reads what it writes.
struct OverrideRow<Value: Equatable & Sendable, Control: View>: View {
  let model: AppModel
  let project: Project
  let setting: WritableKeyPath<ProjectSettings, Value?>
  let label: String
  let info: String
  /// The Global column's cell: what the project follows and where it is set.
  let globalValue: OverrideGlobalValue
  /// What starting an override seeds it with: the value in force, which the
  /// repository's file may have decided.
  let fallback: Value
  /// A value computed live under the row, given whether the project overrides.
  let caption: ((Bool) -> String)?
  /// The project's own value's control, given its binding.
  @ViewBuilder let control: (Binding<Value>) -> Control

  var body: some View {
    let isOverridden = model.overrideToggle(setting, of: project, fallback: fallback)
    VStack(alignment: .leading, spacing: 4) {
      OverrideColumns {
        InfoLabel(label, info: info)
          .fontWeight(isOverridden.wrappedValue ? .semibold : .regular)
      } global: {
        OverrideGlobalCell(model: model, globalValue: globalValue)
      } override: {
        if isOverridden.wrappedValue {
          control(model.overrideField(setting, of: project, fallback: fallback))
            .labelsHidden()
          SettingsSymbolButton.useGlobal { isOverridden.wrappedValue = false }
        } else {
          OverrideStartButton(label: label) { isOverridden.wrappedValue = true }
        }
      }
      if let caption {
        SettingsCaption(caption(isOverridden.wrappedValue))
      }
    }
  }
}
