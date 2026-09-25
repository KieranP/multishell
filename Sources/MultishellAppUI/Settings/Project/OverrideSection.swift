import MultishellAppCore
import MultishellCore
import SwiftUI

/// One project override: the toggle, the control it enables, and what the row
/// says while off. The key path is named once, a wrong one compiling.
struct OverrideSection<Value: Equatable & Sendable, Content: View, Footer: View>: View {
  let model: AppModel
  let project: Project
  let setting: WritableKeyPath<ProjectSettings, Value?>
  let label: String
  let info: String
  /// What the row shows and what turning the override on seeds it with: what
  /// was in force, which the repository's file may have decided.
  let fallback: Value
  /// The control, given the override's binding and whether it is on.
  @ViewBuilder let content: (Binding<Value>, Bool) -> Content
  @ViewBuilder let footer: () -> Footer

  var body: some View {
    let isOverridden = model.ownSettings(of: project)[keyPath: setting] != nil
    Section {
      InfoToggle(
        t("project.override", label), info: info,
        isOn: model.hasOverride(setting, of: project, fallback: fallback))
      content(model.overrideValue(setting, of: project, fallback: fallback), isOverridden)
    } footer: {
      if !isOverridden { footer() }
    }
  }
}

extension OverrideSection where Footer == EmptyView {
  /// An override whose control says for itself what is in force, so there
  /// is nothing left for a footer to add.
  init(
    model: AppModel,
    project: Project,
    setting: WritableKeyPath<ProjectSettings, Value?>,
    label: String,
    info: String,
    fallback: Value,
    @ViewBuilder content: @escaping (Binding<Value>, Bool) -> Content
  ) {
    self.init(
      model: model, project: project, setting: setting, label: label, info: info,
      fallback: fallback, content: content, footer: { EmptyView() })
  }
}

extension OverrideSection {
  /// A setting the repository's file may also set, named once for what the
  /// row inherits and what the override writes.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSetting<Value>,
    global: Value,
    label: String,
    info: String,
    @ViewBuilder content: @escaping (Binding<Value>, Bool, InheritedSetting<Value>) -> Content,
    @ViewBuilder footer: @escaping (InheritedSetting<Value>) -> Footer
  ) {
    let inherited = model.inherited(setting, global: global, for: project)
    self.init(
      model: model, project: project, setting: setting.project, label: label, info: info,
      fallback: inherited.value,
      content: { binding, isOverridden in content(binding, isOverridden, inherited) },
      footer: { footer(inherited) })
  }
}

extension OverrideSection where Footer == EmptyView {
  /// An inheritable setting whose control says for itself where its value
  /// came from.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSetting<Value>,
    global: Value,
    label: String,
    info: String,
    @ViewBuilder content: @escaping (Binding<Value>, Bool, InheritedSetting<Value>) -> Content
  ) {
    self.init(
      model: model, project: project, setting: setting, global: global, label: label, info: info,
      content: content, footer: { _ in EmptyView() })
  }
}

extension OverrideSection where Value == Bool, Content == AnyView, Footer == SettingsCaption {
  /// The plain-toggle override, which is most of them: the label is the
  /// control, so it is given once rather than to both, and the footer is
  /// only what the inherited value says.
  init(
    model: AppModel,
    project: Project,
    setting: InheritableSetting<Bool>,
    global: KeyPath<Workspace, Bool>,
    label: String,
    info: String
  ) {
    self.init(
      model: model, project: project, setting: setting, global: model.workspace[keyPath: global],
      label: label, info: info,
      content: { binding, isOverridden, _ in
        AnyView(Toggle(label, isOn: binding).disabled(!isOverridden))
      },
      footer: { inherited in SettingsCaption(inherited.caption) })
  }
}
