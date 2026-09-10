import MultishellAppCore
import MultishellCore
import SwiftUI

/// One project override: the toggle that turns it on, the control it
/// enables, and what the row says while it is off.
///
/// The key path is named once. Written out at each site it appeared three
/// times over — the toggle, the control's binding, and the `== nil` that
/// disables the control — and a wrong one in any of the three compiles and
/// quietly binds the row to another setting.
struct OverrideSection<Value: Equatable & Sendable, Content: View, Footer: View>: View {
  let model: AppModel
  let project: Project
  let setting: WritableKeyPath<ProjectSettings, Value?>
  let label: String
  let info: String
  /// What the row shows, and what turning the override on seeds it with:
  /// what was actually in force, which `model.inherited(_:global:for:)`
  /// answers where the repository's file may have had the say.
  let fallback: Value
  /// The control, given the override's binding and whether it is on.
  @ViewBuilder let content: (Binding<Value>, Bool) -> Content
  @ViewBuilder let footer: () -> Footer

  var body: some View {
    let isOverridden = model.settings(of: project)[keyPath: setting] != nil
    Section {
      InfoToggle(
        "Override: " + label, info: info,
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

extension OverrideSection where Value == Bool, Content == AnyView {
  /// The plain-toggle override, which is most of them: the label is the
  /// control, so it is given once rather than to both.
  init(
    model: AppModel,
    project: Project,
    setting: WritableKeyPath<ProjectSettings, Bool?>,
    label: String,
    info: String,
    inherited: InheritedFlag,
    @ViewBuilder footer: @escaping () -> Footer
  ) {
    self.init(
      model: model, project: project, setting: setting, label: label, info: info,
      fallback: inherited.value,
      content: { binding, isOverridden in
        AnyView(Toggle(label, isOn: binding).disabled(!isOverridden))
      },
      footer: footer)
  }
}

extension OverrideSection where Value == Bool, Content == AnyView, Footer == SettingsCaption {
  /// The same where the footer is only what the inherited value says, which
  /// is every plain toggle so far.
  init(
    model: AppModel,
    project: Project,
    setting: WritableKeyPath<ProjectSettings, Bool?>,
    label: String,
    info: String,
    inherited: InheritedFlag
  ) {
    self.init(
      model: model, project: project, setting: setting, label: label, info: info,
      inherited: inherited, footer: { SettingsCaption(inherited.caption) })
  }
}
