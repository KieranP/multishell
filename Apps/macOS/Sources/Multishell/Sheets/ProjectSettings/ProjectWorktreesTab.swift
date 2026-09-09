import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectWorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let settings = model.settings(of: project)
    let effective = model.worktreeSettings(for: model.current(project))
    let directory = model.inherited(
      \.worktreeDirectory, global: defaults.worktreeDirectory, for: project)
    let prefix = model.inherited(\.branchPrefix, global: defaults.branchPrefix, for: project)

    Form {
      Section {
        InfoToggle(
          "Override: Worktree path",
          info:
            "Where this project's worktrees are created. {project} is the repository folder name, ~ is home. Relative paths start at the repository.",
          isOn: model.hasOverride(\.worktreeDirectory, of: project, fallback: directory.value))
        TextField(
          "Path:",
          text: model.overrideValue(\.worktreeDirectory, of: project, fallback: directory.value)
        )
        .disabled(settings.worktreeDirectory == nil)
        SettingsCaption(
          "Resolves to \(effective.worktreeContainer(for: project).path)"
            + (settings.worktreeDirectory == nil && directory.isFromRepository
              ? ", from \(SharedProjectSettings.fileName)." : "."))
      }

      Section {
        InfoToggle(
          "Override: Branch prefix",
          info:
            "Prepended to branch names typed in the new-worktree sheet for this project. Turn the override on and leave it blank to use no prefix while the global has one.",
          isOn: model.hasOverride(\.branchPrefix, of: project, fallback: prefix.value))
        TextField(
          "Prefix:",
          text: model.overrideValue(\.branchPrefix, of: project, fallback: prefix.value),
          prompt: Text("none")
        )
        .disabled(settings.branchPrefix == nil)
        SettingsCaption(
          "Typing tabs creates \(effective.qualifiedBranch("tabs")) at \(effective.worktreePath(forBranch: effective.qualifiedBranch("tabs"), in: project).path)"
            + (settings.branchPrefix == nil && prefix.isFromRepository
              ? " The prefix comes from \(SharedProjectSettings.fileName)." : ""))
      }

      Section {
        InfoToggle(
          "Override: Default branch",
          info:
            "The branch this project's work is merged into. A worktree whose branch has landed on it gets a badge in the sidebar saying it can go. Detected from origin/HEAD, then origin/main, origin/master, main, master. A name typed here is looked for on origin before it is looked for locally.",
          isOn: model.hasOverride(\.defaultBranch, of: project, fallback: detected))
        TextField(
          "Branch:",
          text: model.overrideValue(\.defaultBranch, of: project, fallback: detected),
          prompt: Text("main")
        )
        .disabled(settings.defaultBranch == nil)
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
