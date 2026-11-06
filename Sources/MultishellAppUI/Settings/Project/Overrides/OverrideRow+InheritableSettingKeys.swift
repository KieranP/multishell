import MultishellAppCore
import MultishellCore
import SwiftUI

extension OverrideRow {
  /// A setting the repository's file may also set, named once for what the row
  /// inherits and writes. `globalValue` words the value in force, the file's or the global's.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSettingKeys<Value>,
    global: Value,
    label: String,
    info: String,
    globalValue: (InheritedSetting<Value>) -> OverrideGlobalValue,
    caption: ((Bool) -> String)? = nil,
    @ViewBuilder control: @escaping (Binding<Value>) -> Control,
  ) {
    let inherited = model.inherited(setting, global: global, for: project)
    self.init(
      model: model,
      project: project,
      setting: setting.project,
      label: label,
      info: info,
      globalValue: globalValue(inherited),
      fallback: inherited.value,
      caption: caption,
      control: control,
    )
  }
}

extension OverrideRow where Value == Bool, Control == SettingsSwitch {
  /// The plain switch, most of them, its global set on `globalSection`.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSettingKeys<Bool>,
    globalSetting: KeyPath<Workspace, Bool>,
    label: String,
    info: String,
    globalSection: SettingsSection?,
  ) {
    self.init(
      model: model,
      project: project,
      setting: setting,
      global: model.workspace[keyPath: globalSetting],
      label: label,
      info: info,
      globalValue: { $0.globalValue(setIn: globalSection) },
      control: { SettingsSwitch(label: label, isOn: $0) },
    )
  }
}
