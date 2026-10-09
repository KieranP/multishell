import MultishellAppCore
import MultishellCore
import SwiftUI

/// Four scripts and two file lists, one operation's group at a time; see
/// Docs/design/settings.md. An inherited hook is grey, its trust above all.
struct ProjectHooksPage: View {
  enum Part: CaseIterable {
    case create
    case delete
    case environment

    var title: String {
      switch self {
      case .create: t("hooks.create")
      case .delete: t("hooks.delete")
      case .environment: t("hooks.environment")
      }
    }
  }

  let model: AppModel
  let project: Project

  @State private var part: Part

  init(model: AppModel, project: Project, part: Part = .create) {
    self.model = model
    self.project = project
    _part = State(initialValue: part)
  }

  var body: some View {
    let shared = project.sharedSettingsSnapshot.confined
    Form {
      if let shared, shared.asksForTrust {
        SharedSettingsTrustSection(model: model, project: project)
      } else if let problem = project.sharedSettingsSnapshot.problem {
        Section { SettingsCaption(problem) }
      }

      SplitPagePicker(label: t("settings.hooks"), selection: $part, title: \.title)

      switch part {
      case .create: createSection(shared)
      case .delete: deleteSection(shared)
      case .environment: HookEnvironmentSection(model: model)
      }
    }
    .formStyle(.grouped)
  }

  private func createSection(_ shared: SharedProjectSettings?) -> some View {
    Section {
      MonospacedEditor(
        title: t("hooks.pre-create"), info: t("hooks.pre-create-info"),
        placeholder: shared?.preCreateHook,
        text: model.settingBinding(\.preCreateHook, of: project))
      MonospacedEditor(
        title: t("hooks.linked-paths"),
        info: t("hooks.linked-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.linkedPaths,
        text: model.settingBinding(\.linkedPaths, of: project))
      MonospacedEditor(
        title: t("hooks.copied-paths"),
        info: t("hooks.copied-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.copiedPaths,
        text: model.settingBinding(\.copiedPaths, of: project))
      MonospacedEditor(
        title: t("hooks.post-create"), info: t("hooks.post-create-info"),
        placeholder: shared?.postCreateHook,
        text: model.settingBinding(\.postCreateHook, of: project))
    }
  }

  private func deleteSection(_ shared: SharedProjectSettings?) -> some View {
    Section {
      MonospacedEditor(
        title: t("hooks.pre-delete"), info: t("hooks.pre-delete-info"),
        placeholder: shared?.preDeleteHook,
        text: model.settingBinding(\.preDeleteHook, of: project))
      MonospacedEditor(
        title: t("hooks.post-delete"), info: t("hooks.post-delete-info"),
        placeholder: shared?.postDeleteHook,
        text: model.settingBinding(\.postDeleteHook, of: project))
    }
  }
}
