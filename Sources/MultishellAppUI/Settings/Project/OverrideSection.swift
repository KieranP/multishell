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
        isOn: model.overrideToggle(setting, of: project, fallback: fallback))
      content(model.overrideField(setting, of: project, fallback: fallback), isOverridden)
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
