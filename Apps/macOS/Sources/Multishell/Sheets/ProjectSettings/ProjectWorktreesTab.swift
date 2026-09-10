import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectWorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let effective = model.worktreeSettings(for: model.current(project))
    let directory = model.inherited(
      \.worktreeDirectory, global: defaults.worktreeDirectory, for: project)
    let prefix = model.inherited(\.branchPrefix, global: defaults.branchPrefix, for: project)
    let branch = effective.qualifiedBranch("tabs")

    Form {
      OverrideSection(
        model: model, project: project, setting: \.worktreeDirectory,
        label: "Worktree path",
        info:
          "Where this project's worktrees are created. {project} is the repository folder name, ~ is home. Relative paths start at the repository.",
        fallback: directory.value
      ) { path, isOverridden in
        TextField("Path:", text: path).disabled(!isOverridden)
        SettingsCaption(
          "Resolves to \(effective.worktreeContainer(for: project).path)"
            + (!isOverridden && directory.isFromRepository
              ? ", from \(SharedProjectSettings.fileName)." : "."))
      }

      OverrideSection(
        model: model, project: project, setting: \.branchPrefix,
        label: "Branch prefix",
        info:
          "Prepended to branch names typed in the new-worktree sheet for this project. Turn the override on and leave it blank to use no prefix while the global has one.",
        fallback: prefix.value
      ) { text, isOverridden in
        TextField("Prefix:", text: text, prompt: Text("none")).disabled(!isOverridden)
        SettingsCaption(
          "Typing tabs creates \(branch) at \(effective.worktreePath(forBranch: branch, in: project).path)"
            + (!isOverridden && prefix.isFromRepository
              ? " The prefix comes from \(SharedProjectSettings.fileName)." : ""))
      }

      OverrideSection(
        model: model, project: project, setting: \.defaultBranch,
        label: "Default branch",
        info:
          "The branch this project's work is merged into. A worktree whose branch has landed on it gets a badge in the sidebar saying it can go. Detected from origin/HEAD, then origin/main, origin/master, main, master. A name typed here is looked for on origin before it is looked for locally.",
        fallback: detected
      ) { text, isOverridden in
        TextField("Branch:", text: text, prompt: Text("main")).disabled(!isOverridden)
        SettingsCaption(
          model.mergeBase(of: project).map { "Merges are measured against \($0.ref)." }
            ?? "No branch to measure merges against, so no worktree is badged as merged.")
      }
    }
    .formStyle(.grouped)
  }

  /// What the field shows while the override is off: the branch the model
  /// resolved, which already carries what the repository's file says, and
  /// without the remote it was found on, so turning the override on seeds
  /// `main` rather than `origin/main`.
  private var detected: String {
    model.mergeBase(of: project)?.branch ?? "main"
  }
}
