import MultishellAppCore
import MultishellCore
import SwiftUI

/// Four scripts and two file lists, one sidebar part at a time; see
/// Docs/design/settings.md. An inherited hook is grey, its trust above all.
struct ProjectHooksPage: View {
  let model: AppModel
  let project: Project
  /// One of the Hooks page's parts.
  let section: SettingsSection

  var body: some View {
    let shared = project.sharedSettingsSnapshot.confined
    SettingsForm {
      if let shared, shared.asksForTrust {
        SharedSettingsTrustSection(model: model, project: project)
      } else if let problem = project.sharedSettingsSnapshot.problem {
        SettingsGroup { SettingsCaption(problem) }
      }

      switch section {
      case .hooksCreate: createSection(shared)
      case .hooksDelete: deleteSection(shared)
      case .hooksEnvironment: HookEnvironmentSection(model: model)

      case .agentHooks, .agents, .agentSettings, .appearance, .general, .integrations,
        .notifications, .terminal, .worktrees:
        EmptyView()
      }
    }
  }

  private func createSection(_ shared: SharedProjectSettings?) -> some View {
    SettingsGroup {
      MonospacedEditor(
        label: t("hooks.pre-create"),
        info: t("hooks.pre-create-info"),
        placeholder: shared?.preCreateHook,
        text: model.settingBinding(\.preCreateHook, of: project),
      )
      MonospacedEditor(
        label: t("hooks.linked-paths"),
        info: t("hooks.linked-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.linkedPaths,
        text: model.settingBinding(\.linkedPaths, of: project),
      )
      MonospacedEditor(
        label: t("hooks.copied-paths"),
        info: t("hooks.copied-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.copiedPaths,
        text: model.settingBinding(\.copiedPaths, of: project),
      )
      MonospacedEditor(
        label: t("hooks.post-create"),
        info: t("hooks.post-create-info"),
        placeholder: shared?.postCreateHook,
        text: model.settingBinding(\.postCreateHook, of: project),
      )
    }
  }

  private func deleteSection(_ shared: SharedProjectSettings?) -> some View {
    SettingsGroup {
      MonospacedEditor(
        label: t("hooks.pre-delete"),
        info: t("hooks.pre-delete-info"),
        placeholder: shared?.preDeleteHook,
        text: model.settingBinding(\.preDeleteHook, of: project),
      )
      MonospacedEditor(
        label: t("hooks.post-delete"),
        info: t("hooks.post-delete-info"),
        placeholder: shared?.postDeleteHook,
        text: model.settingBinding(\.postDeleteHook, of: project),
      )
    }
  }
}
