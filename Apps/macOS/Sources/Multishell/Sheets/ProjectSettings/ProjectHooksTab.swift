import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// Four scripts and the two lists of files a new worktree is given, grouped
/// by the operation they surround. Each is a small monospaced editor, since
/// a hook of any substance has more than one line.
/// Where the repository's `.multishell.json` has a hook and the user's is
/// blank, the editor shows the repository's in grey, and a section above
/// says whether those hooks are trusted.
struct ProjectHooksTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let current = model.current(project)
    let shared = model.sharedSettings[project.id]
    Form {
      if let shared, shared.hasHooks {
        sharedHooksSection(shared, project: current)
      } else if let problem = model.sharedSettings.problem(of: project.id) {
        Section { SettingsCaption(problem) }
      }

      Section(t("hooks.create")) {
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

      Section(t("hooks.delete")) {
        MonospacedEditor(
          title: t("hooks.pre-delete"), info: t("hooks.pre-delete-info"),
          placeholder: shared?.preDeleteHook,
          text: model.setting(\.preDeleteHook, of: project))
        MonospacedEditor(
          title: t("hooks.post-delete"), info: t("hooks.post-delete-info"),
          placeholder: shared?.postDeleteHook,
          text: model.setting(\.postDeleteHook, of: project))
      }

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
    .formStyle(.grouped)
  }

  /// The repository's hooks run only once trusted, and a change to them
  /// asks again; the grey text in the editors above is what they are.
  private func sharedHooksSection(_ shared: SharedProjectSettings, project: Project) -> some View {
    let trusted = model.trustsSharedHooks(of: project)
    return Section {
      HStack(spacing: 8) {
        Text(trusted ? t("hooks.shared-run") : t("hooks.shared-ignored"))
        Spacer()
        Button(trusted ? t("hooks.stop-trusting") : t("hooks.trust")) {
          model.setTrustsSharedHooks(!trusted, for: project)
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

/// One multi-line monospaced field: a hook's script, or one of the file
/// lists.
///
/// The only placeholder passed is what the repository ships, so grey text
/// means that and nothing else. No example scripts: an example drawn the
/// same way as an inherited one left no way to tell a suggestion from what
/// would really run.
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
