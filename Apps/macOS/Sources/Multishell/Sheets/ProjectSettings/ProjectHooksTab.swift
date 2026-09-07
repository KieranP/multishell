import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// Four scripts, grouped by the operation they surround. Each is a small
/// monospaced editor, since a hook of any substance has more than one line.
/// Where the repository's `.multishell.json` has a hook and the user's is
/// blank, the editor shows the repository's as its placeholder, and a
/// section above says whether those hooks are trusted.
struct ProjectHooksTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let current = model.current(project)
    let shared = model.sharedSettings[project.id]
    Form {
      if let shared, shared.hasHooks {
        sharedHooksSection(shared, project: current)
      } else if let problem = model.sharedSettingsProblems[project.id] {
        Section { SettingsCaption(problem) }
      }

      Section("Create") {
        HookEditor(
          title: "Pre-create",
          info:
            "Runs in the repository before git worktree add, with MULTISHELL_WORKTREE_PATH set to the planned path. A non-zero exit stops the create; git is never asked.",
          placeholder: shared?.preCreateHook
            ?? "test -n \"$TICKET\" || { echo 'set TICKET first' >&2; exit 1; }",
          text: model.setting(\.preCreateHook, of: project))
        HookEditor(
          title: "Post-create",
          info:
            "Runs in the new worktree after git worktree add. A failure is reported; the worktree stays.",
          placeholder: shared?.postCreateHook
            ?? "npm install\ncp \"$MULTISHELL_PROJECT_PATH/.env\" .",
          text: model.setting(\.postCreateHook, of: project))
      }

      Section("Delete") {
        HookEditor(
          title: "Pre-delete",
          info:
            "Runs in the worktree before git worktree remove, after the confirmation. A non-zero exit stops the removal; the worktree stays.",
          placeholder: shared?.preDeleteHook
            ?? "test -z \"$(git log @{upstream}.. 2>/dev/null)\" || exit 1",
          text: model.setting(\.preDeleteHook, of: project))
        HookEditor(
          title: "Post-delete",
          info: "Runs in the repository after git worktree remove, once the directory is gone.",
          placeholder: shared?.postDeleteHook ?? "Optional shell script",
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
          Text("Environment")
          InfoButton(
            "Each script runs through this project's shell (the Terminal tab; $SHELL unless chosen) as an interactive login shell, with these variables set, so nothing needs quoting. In sh, bash and zsh the first failing line stops the script and is the one reported; fish runs the whole script. A hook still running at the timeout in Settings > Worktrees is stopped."
          )
        }
      }
    }
    .formStyle(.grouped)
  }

  /// The repository's hooks run only once trusted, and a change to them
  /// asks again; the placeholders above show what they are.
  private func sharedHooksSection(_ shared: SharedProjectSettings, project: Project) -> some View {
    let trusted = model.trustsSharedHooks(of: project)
    return Section {
      HStack(spacing: 8) {
        Text(
          trusted
            ? "Its hooks run where yours are blank."
            : "Its hooks are shown as placeholders and do not run.")
        Spacer()
        Button(trusted ? "Stop Trusting" : "Trust Hooks") {
          model.setTrustsSharedHooks(!trusted, for: project)
        }
        .controlSize(.small)
      }
    } header: {
      HStack(spacing: 6) {
        Text("From \(SharedProjectSettings.fileName)")
        InfoButton(
          "The repository ships hooks in \(SharedProjectSettings.fileName) at its root. They run code through your shell, so they are off until you trust them, and a change to their text asks again. A whitespace-only hook of your own turns the repository's off for that stage."
        )
      }
    }
  }

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
