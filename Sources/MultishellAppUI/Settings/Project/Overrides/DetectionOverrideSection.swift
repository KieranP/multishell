import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project override picked from what detection found, an agent or a shell,
/// naming the global choice while it is off.
struct DetectionOverrideSection: View {
  let model: AppModel
  let project: Project
  let setting: WritableKeyPath<ProjectSettings, String?>
  let label: String
  let info: String
  let pickerLabel: String
  let pickerInfo: String
  let options: (String) -> [DetectionOption]
  let globalID: String
  let globalName: String

  var body: some View {
    OverrideSection(
      model: model,
      project: project,
      setting: setting,
      label: label,
      info: info,
      fallback: globalID,
    ) { selection, isOverridden in
      DetectionPicker(
        label: pickerLabel,
        selection: selection,
        options: options,
        rescanning: model,
        info: pickerInfo,
        isEnabled: isOverridden,
      )
    } footer: {
      SettingsCaption(t("project.using-global-value", globalName))
    }
  }
}
