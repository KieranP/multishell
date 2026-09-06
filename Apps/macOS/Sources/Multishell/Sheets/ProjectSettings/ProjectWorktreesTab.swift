import MultishellCore
import SwiftUI

struct ProjectWorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let effective = settings.effective(defaults: defaults)

    Form {
      Section {
        InfoToggle(
          "Override worktree path",
          info:
            "Where this project's worktrees are created. {project} is the repository folder name, ~ is home. Relative paths start at the repository.",
          isOn: overrides(\.worktreeDirectory, default: defaults.worktreeDirectory))
        TextField("Path:", text: text(\.worktreeDirectory, fallback: defaults.worktreeDirectory))
          .disabled(settings.worktreeDirectory == nil)
        SettingsCaption("Resolves to \(effective.worktreeContainer(for: project).path)")
      }

      Section {
        InfoToggle(
          "Override branch prefix",
          info:
            "Prepended to branch names typed in the new-worktree sheet for this project. Turn the override on and leave it blank to use no prefix while the global has one.",
          isOn: overrides(\.branchPrefix, default: defaults.branchPrefix))
        TextField(
          "Prefix:", text: text(\.branchPrefix, fallback: defaults.branchPrefix),
          prompt: Text("none")
        )
        .disabled(settings.branchPrefix == nil)
        SettingsCaption(
          "Typing tabs creates \(effective.qualifiedBranch("tabs")) at \(effective.worktreePath(forBranch: effective.qualifiedBranch("tabs"), in: project).path)"
        )
      }
    }
    .formStyle(.grouped)
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
