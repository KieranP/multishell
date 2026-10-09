import MultishellAppCore
import MultishellCore
import SwiftUI

extension OverrideSection {
  /// A setting the repository's file may also set, named once for what the
  /// row inherits and what the override writes.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSettingKeys<Value>,
    global: Value,
    label: String,
    info: String,
    @ViewBuilder content: @escaping (Binding<Value>, Bool, InheritedSetting<Value>) -> Content,
    @ViewBuilder footer: @escaping (InheritedSetting<Value>) -> Footer,
  ) {
    let inherited = model.inherited(setting, global: global, for: project)
    self.init(
      model: model,
      project: project,
      setting: setting.project,
      label: label,
      info: info,
      fallback: inherited.value,
      content: { binding, isOverridden in content(binding, isOverridden, inherited) },
      footer: { footer(inherited) },
    )
  }
}

extension OverrideSection where Footer == EmptyView {
  /// An inheritable setting whose control says for itself where its value
  /// came from.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSettingKeys<Value>,
    global: Value,
    label: String,
    info: String,
    @ViewBuilder content: @escaping (Binding<Value>, Bool, InheritedSetting<Value>) -> Content,
  ) {
    self.init(
      model: model,
      project: project,
      setting: setting,
      global: global,
      label: label,
      info: info,
      content: content,
      footer: { _ in EmptyView() },
    )
  }
}

extension OverrideSection where Value == Bool, Content == AnyView, Footer == SettingsCaption {
  /// The plain-toggle override, most of them: the label is the control, given
  /// once, and the footer is only what the inherited value says.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSettingKeys<Bool>,
    global: KeyPath<Workspace, Bool>,
    label: String,
    info: String,
  ) {
    self.init(
      model: model,
      project: project,
      setting: setting,
      global: model.workspace[keyPath: global],
      label: label,
      info: info,
      content: { binding, isOverridden, _ in
        AnyView(Toggle(label, isOn: binding).disabled(!isOverridden))
      },
      footer: { inherited in SettingsCaption(inherited.caption) },
    )
  }
}
