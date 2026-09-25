import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// Four scripts and two file lists, one operation's group at a time; see
/// Docs/design/settings.md. An inherited hook is grey, its trust above all.
struct ProjectHooksTab: View {
  enum Stage: CaseIterable {
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

  @State private var stage: Stage

  init(model: AppModel, project: Project, stage: Stage = .create) {
    self.model = model
    self.project = project
    _stage = State(initialValue: stage)
  }

  var body: some View {
    let shared = project.sharedSettings.confined
    Form {
      if let shared, shared.asksForTrust {
        sharedSettingsSection(shared, project: project)
      } else if let problem = project.sharedSettings.problem {
        Section { SettingsCaption(problem) }
      }

      Section {
        Picker(t("settings.hooks"), selection: $stage) {
          ForEach(Stage.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .segmentedAcrossRow()
      }

      switch stage {
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
      HStack(spacing: 6) {
        Text(t("hooks.environment"))
        InfoButton(t("hooks.environment-info"))
      }
    }
  }

  /// What the repository asks for is used only once trusted, and a change
  /// asks again; the grey text in the editors above is what it is.
  private func sharedSettingsSection(
    _ shared: SharedProjectSettings, project: Project
  )
    -> some View
  {
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
      HStack(spacing: 6) {
        Text(t("hooks.shared-header", SharedProjectSettings.fileName))
        InfoButton(t("hooks.shared-info", SharedProjectSettings.fileName))
      }
    }
  }

}

/// One multi-line monospaced field: a hook's script, or a file list. The only
/// placeholder is what the repository ships, so grey means that alone.
private struct MonospacedEditor: View {
  let title: String
  let info: String
  let placeholder: String?
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      InfoLabel(title, info: info)
      TextEditor(text: $text)
        .font(.system(size: 11, design: .monospaced))
        .scrollContentBackground(.hidden)
        .frame(minHeight: 48, maxHeight: 96)
        .padding(4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .topLeading) {
          if text.isEmpty, let placeholder {
            Text(placeholder)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.tertiary)
              .padding(.horizontal, 9)
              .padding(.vertical, 4)
              .allowsHitTesting(false)
          }
        }
    }
    .padding(.vertical, 2)
  }
}
