import MultishellAppCore
import MultishellCore
import MultishellGitKit
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
    let shared = project.sharedSettings.confined
    Form {
      if let shared, shared.asksForTrust {
        sharedSettingsSection(shared)
      } else if let problem = project.sharedSettings.problem {
        Section { SettingsCaption(problem) }
      }

      PartPicker(label: t("settings.hooks"), selection: $part, title: \.title)

      switch part {
      case .create: createSection(shared)
      case .delete: deleteSection(shared)
      case .environment: environmentSection
      }
    }
    .formStyle(.grouped)
  }

  private func createSection(_ shared: SharedProjectSettings?) -> some View {
    Section {
      MonospacedEditor(
        title: t("hooks.pre-create"), info: t("hooks.pre-create-info"),
        placeholder: shared?.preCreateHook,
        text: model.setting(\.preCreateHook, of: project))
      MonospacedEditor(
        title: t("hooks.linked-paths"),
        info: t("hooks.linked-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.linkedPaths,
        text: model.setting(\.linkedPaths, of: project))
      MonospacedEditor(
        title: t("hooks.copied-paths"),
        info: t("hooks.copied-paths-info", SharedProjectSettings.fileName),
        placeholder: shared?.copiedPaths,
        text: model.setting(\.copiedPaths, of: project))
      MonospacedEditor(
        title: t("hooks.post-create"), info: t("hooks.post-create-info"),
        placeholder: shared?.postCreateHook,
        text: model.setting(\.postCreateHook, of: project))
    }
  }

  private func deleteSection(_ shared: SharedProjectSettings?) -> some View {
    Section {
      MonospacedEditor(
        title: t("hooks.pre-delete"), info: t("hooks.pre-delete-info"),
        placeholder: shared?.preDeleteHook,
        text: model.setting(\.preDeleteHook, of: project))
      MonospacedEditor(
        title: t("hooks.post-delete"), info: t("hooks.post-delete-info"),
        placeholder: shared?.postDeleteHook,
        text: model.setting(\.postDeleteHook, of: project))
    }
  }

  private var environmentSection: some View {
    Section {
      ForEach(HookVariable.allCases, id: \.self) { variable in
        LabeledContent {
          Text(variable.meaning).foregroundStyle(.secondary)
        } label: {
          HStack(spacing: 4) {
            Text(variable.name).font(.system(size: 11, design: .monospaced))
            CopyButton("$\(variable.name)", model: model)
          }
        }
      }
    } header: {
      InfoLabel(t("hooks.environment"), info: t("hooks.environment-info"), spacing: 6)
    }
  }

  /// What the repository asks for is used only once trusted, and a change
  /// asks again; the grey text in the editors above is what it is.
  private func sharedSettingsSection(_ shared: SharedProjectSettings) -> some View {
    let trusted = model.trustsSharedSettings(of: project)
    return Section {
      HStack(spacing: 8) {
        Text(trusted ? t("hooks.shared-run") : t("hooks.shared-ignored"))
        Spacer()
        Button(trusted ? t("hooks.stop-trusting") : t("hooks.trust")) {
          model.setTrustsSharedSettings(!trusted, for: project)
        }
        .controlSize(.small)
      }
    } header: {
      InfoLabel(
        t("hooks.shared-header", SharedProjectSettings.fileName),
        info: t("hooks.shared-info", SharedProjectSettings.fileName), spacing: 6)
    }
  }
}
