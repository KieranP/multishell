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
      } else if let problem = model.sharedSettingsProblems[project.id] {
        Section { SettingsCaption(problem) }
      }

      Section("Create") {
        MonospacedEditor(
          title: "Pre-create",
          info:
            "Runs in the repository before git worktree add, with MULTISHELL_WORKTREE_PATH set to the planned path. A non-zero exit stops the create; git is never asked.",
          placeholder: shared?.preCreateHook,
          text: model.setting(\.preCreateHook, of: project))
        MonospacedEditor(
          title: "Link into new worktrees",
          info:
            "Symlinked in the new worktree back to the repository's own file after git worktree add, before the copy list and the post-create hook, so the hook and the first terminal both find them. For what a worktree can share rather than hold twice: a folder is linked whole, so node_modules or a build cache is one directory again, and writing through the link writes the repository's file. One path per line, relative to the repository root, with the same patterns and the same skipping as the copy list below. A path leading outside the repository or the worktree is not linked and is named afterwards. A list in \(SharedProjectSettings.fileName) fills a blank one here without being trusted first, since linking runs nothing.",
          placeholder: shared?.linkedPaths,
          text: model.setting(\.linkedPaths, of: project))
        MonospacedEditor(
          title: "Copy into new worktrees",
          info:
            "Copied out of the repository after the link list, before the post-create hook, so the hook and the first terminal both find them. For what the worktree wants its own of: an .env it will edit. One path per line, relative to the repository root; a folder is copied whole. A name may be a pattern: * for any run of characters and ? for one, neither crossing a /, so .env.* takes .env.local and .env.test. A pattern matches a name starting with a dot only when it spells the dot, as a shell does. A path the repository does not have, or one git or the link list already put in the worktree, is skipped, and a path leading outside the repository or the worktree is not copied and is named afterwards. A list in \(SharedProjectSettings.fileName) fills a blank one here without being trusted first, since copying runs nothing.",
          placeholder: shared?.copiedPaths,
          text: model.setting(\.copiedPaths, of: project))
        MonospacedEditor(
          title: "Post-create",
          info:
            "Runs in the new worktree after git worktree add. A failure is reported; the worktree stays.",
          placeholder: shared?.postCreateHook,
          text: model.setting(\.postCreateHook, of: project))
      }

      Section("Delete") {
        MonospacedEditor(
          title: "Pre-delete",
          info:
            "Runs in the worktree before git worktree remove, after the confirmation. A non-zero exit stops the removal; the worktree stays.",
          placeholder: shared?.preDeleteHook,
          text: model.setting(\.preDeleteHook, of: project))
        MonospacedEditor(
          title: "Post-delete",
          info: "Runs in the repository after git worktree remove, once the directory is gone.",
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
  /// asks again; the grey text in the editors above is what they are.
  private func sharedHooksSection(_ shared: SharedProjectSettings, project: Project) -> some View {
    let trusted = model.trustsSharedHooks(of: project)
    return Section {
      HStack(spacing: 8) {
        Text(
          trusted
            ? "Its hooks run where yours are blank."
            : "Its hooks are shown in grey above and do not run.")
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
          "The repository ships hooks in \(SharedProjectSettings.fileName) at its root. They run code through your shell, so they are off until you trust them, and an edit to the file asks again unless you have answered for those exact contents before, so switching to a branch whose file you have already answered for does not ask. A whitespace-only hook of your own turns the repository's off for that stage."
        )
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
