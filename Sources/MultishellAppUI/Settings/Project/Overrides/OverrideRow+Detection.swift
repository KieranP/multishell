import MultishellAppCore
import MultishellCore
import SwiftUI

extension OverrideRow where Value == String, Control == DetectionMenu {
  /// A project's choice from what detection found, an agent or a shell, the
  /// global's choice named in the Global column and seeding the override.
  init(
    model: AppModel,
    project: Project,
    setting: WritableKeyPath<ProjectSettings, String?>,
    label: String,
    info: String,
    options: @escaping (String) -> [DetectionOption],
    column: OverrideGlobalValue,
    globalID: String,
  ) {
    self.init(
      model: model,
      project: project,
      setting: setting,
      label: label,
      info: info,
      column: column,
      fallback: globalID,
      caption: nil,
    ) { selection in
      DetectionMenu(
        label: label,
        selection: selection,
        options: options,
        refresh: DetectionMenu.refreshingLogin(of: model),
      )
    }
  }
}
