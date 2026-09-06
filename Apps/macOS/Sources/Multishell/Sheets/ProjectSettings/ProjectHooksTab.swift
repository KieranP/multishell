import MultishellCore
import SwiftUI

/// Four scripts, grouped by the operation they surround. Each is a small
/// monospaced editor, since a hook of any substance has more than one line.
struct ProjectHooksTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    Form {
      Section("Create") {
        HookEditor(
          title: "Pre-create",
          info:
            "Runs in the repository before git worktree add, with MULTISHELL_WORKTREE_PATH set to the planned path. A non-zero exit stops the create; git is never asked.",
          placeholder: "test -n \"$TICKET\" || { echo 'set TICKET first' >&2; exit 1; }",
          text: projectSetting(\.preCreateHook, of: project, in: model))
        HookEditor(
          title: "Post-create",
          info:
            "Runs in the new worktree after git worktree add. A failure is reported; the worktree stays.",
          placeholder: "npm install\ncp \"$MULTISHELL_PROJECT_PATH/.env\" .",
          text: projectSetting(\.postCreateHook, of: project, in: model))
      }

      Section("Delete") {
        HookEditor(
          title: "Pre-delete",
          info:
            "Runs in the worktree before git worktree remove, after the confirmation. A non-zero exit stops the removal; the worktree stays.",
          placeholder: "test -z \"$(git log @{upstream}.. 2>/dev/null)\" || exit 1",
          text: projectSetting(\.preDeleteHook, of: project, in: model))
        HookEditor(
          title: "Post-delete",
          info: "Runs in the repository after git worktree remove, once the directory is gone.",
          placeholder: "Optional shell script",
          text: projectSetting(\.postDeleteHook, of: project, in: model))
      }

      Section {
        ForEach(Self.hookVariables, id: \.name) { variable in
          LabeledContent {
            Text(variable.meaning).foregroundStyle(.secondary)
          } label: {
            Text(variable.name).font(.system(size: 11, design: .monospaced))
          }
        }
      } header: {
        HStack(spacing: 6) {
          Text("Environment")
          InfoButton(
            "Each script runs through this project's shell (the Terminal tab; $SHELL unless chosen) as an interactive login shell, with these variables set, so nothing needs quoting. In sh, bash and zsh the first failing line stops the script and is the one reported; fish runs the whole script."
          )
        }
      }
    }
    .formStyle(.grouped)
  }

  private static let hookVariables: [(name: String, meaning: String)] = [
    ("MULTISHELL_PROJECT_PATH", "Repository root"),
    ("MULTISHELL_PROJECT_NAME", "Repository folder name"),
    ("MULTISHELL_WORKTREE_PATH", "The worktree created or removed"),
    ("MULTISHELL_BRANCH", "Its branch"),
  ]
}

private struct HookEditor: View {
  let title: String
  let info: String
  let placeholder: String
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
          if text.isEmpty {
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
