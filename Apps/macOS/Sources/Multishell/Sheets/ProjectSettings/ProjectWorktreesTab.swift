import MultishellCore
import SwiftUI

struct ProjectWorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let effective = model.worktreeSettings(for: model.workspace.project(project.id) ?? project)
    let shared = model.sharedSettings[project.id]

    Form {
      Section {
        InfoToggle(
          "Override worktree path",
          info:
            "Where this project's worktrees are created. {project} is the repository folder name, ~ is home. Relative paths start at the repository.",
          isOn: overrides(\.worktreeDirectory, default: defaults.worktreeDirectory))
        TextField(
          "Path:",
          text: text(
            \.worktreeDirectory, fallback: shared?.worktreeDirectory ?? defaults.worktreeDirectory)
        )
        .disabled(settings.worktreeDirectory == nil)
        SettingsCaption(
          "Resolves to \(effective.worktreeContainer(for: project).path)"
            + (settings.worktreeDirectory == nil && shared?.worktreeDirectory != nil
              ? ", from \(SharedProjectSettings.fileName)." : "."))
      }

      Section {
        InfoToggle(
          "Override branch prefix",
          info:
            "Prepended to branch names typed in the new-worktree sheet for this project. Turn the override on and leave it blank to use no prefix while the global has one.",
          isOn: overrides(\.branchPrefix, default: defaults.branchPrefix))
        TextField(
          "Prefix:",
          text: text(\.branchPrefix, fallback: shared?.branchPrefix ?? defaults.branchPrefix),
          prompt: Text("none")
        )
        .disabled(settings.branchPrefix == nil)
        SettingsCaption(
          "Typing tabs creates \(effective.qualifiedBranch("tabs")) at \(effective.worktreePath(forBranch: effective.qualifiedBranch("tabs"), in: project).path)"
            + (settings.branchPrefix == nil && shared?.branchPrefix != nil
              ? " The prefix comes from \(SharedProjectSettings.fileName)." : ""))
      }

      Section {
        InfoToggle(
          "Override default branch",
          info:
            "The branch this project's work is merged into. A worktree whose branch has landed on it gets a badge in the sidebar saying it can go. Detected from origin/HEAD, then origin/main, origin/master, main, master. A name typed here is looked for on origin before it is looked for locally.",
          isOn: overrides(\.defaultBranch, default: detected))
        TextField(
          "Branch:", text: text(\.defaultBranch, fallback: detected), prompt: Text("main")
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
  /// resolved, without the remote it was found on, so turning the override
  /// on seeds `main` rather than `origin/main`.
  private var detected: String {
    model.mergeBase(of: project)?.branch ?? "main"
  }

  /// Turning an override on seeds it with the global value so the field is
  /// never blank; turning it off returns to following the global.
  private func overrides(
    _ keyPath: WritableKeyPath<ProjectSettings, String?>, default value: String
  )
    -> Binding<Bool>
  {
    let source = projectSetting(keyPath, of: project, in: model)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? (source.wrappedValue ?? value) : nil }
    )
  }

  /// Shows the global value while the override is off, so the disabled
  /// field reads as what is in effect rather than as empty.
  private func text(
    _ keyPath: WritableKeyPath<ProjectSettings, String?>, fallback: String
  ) -> Binding<String> {
    let source = projectSetting(keyPath, of: project, in: model)
    return Binding(
      get: { source.wrappedValue ?? fallback },
      set: { source.wrappedValue = $0 }
    )
  }
}
