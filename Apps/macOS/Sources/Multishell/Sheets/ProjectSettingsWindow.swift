import MultishellCore
import SwiftUI

/// Per-project settings, as a window that matches Multishell > Settings:
/// icon tabs in the toolbar, changes applied as they are made, closed with
/// the window's own close button.
struct ProjectSettingsWindow: View {
  static let windowID = "project-settings"

  let model: AppModel
  let projectID: Project.ID

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let project = model.workspace.project(projectID) {
      ToolbarTabs(tabs: [
        .init("General", symbol: "folder") { GeneralTab(model: model, project: project) },
        .init("Worktrees", symbol: "arrow.trianglehead.branch") {
          WorktreesTab(model: model, project: project)
        },
        .init("Hooks", symbol: "terminal") { HooksTab(model: model, project: project) },
      ])
      .frame(width: 560, height: 400)
      .navigationTitle("\(project.name) Settings")
    } else {
      // The project was removed while this window was open.
      Color.clear.frame(width: 1, height: 1).onAppear { dismiss() }
    }
  }
}

/// A binding into the project's settings that writes straight to the store.
@MainActor
private func setting<Value>(
  _ keyPath: WritableKeyPath<ProjectSettings, Value>, of project: Project, in model: AppModel
) -> Binding<Value> {
  Binding(
    get: {
      model.workspace.project(project.id)?.settings[keyPath: keyPath]
        ?? project.settings[keyPath: keyPath]
    },
    set: { value in
      var settings = model.workspace.project(project.id)?.settings ?? project.settings
      settings[keyPath: keyPath] = value
      model.updateSettings(settings, for: project)
    }
  )
}

private struct GeneralTab: View {
  let model: AppModel
  let project: Project
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    Form {
      Section {
        LabeledContent("Repository:") {
          HStack {
            Text(project.path.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
            Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([project.path]) }
              .controlSize(.small)
          }
        }
        LabeledContent("Worktrees:") {
          HStack {
            Text("\(worktrees.count) discovered")
            Button("Refresh") { Task { await model.refreshRequested(project) } }
              .controlSize(.small)
          }
        }
      }

      Section {
        Toggle(
          "Ask before removing a worktree",
          isOn: setting(\.confirmsWorktreeRemoval, of: project, in: model))
        SettingsCaption(
          "The confirmation also warns about uncommitted changes and open terminals in that worktree."
        )
      }

      Section {
        Button("Remove Project…", role: .destructive) {
          model.removeProject(project)
          dismiss()
        }
        SettingsCaption(
          "Takes the project out of the sidebar and closes its terminals. Nothing on disk is touched."
        )
      }
    }
    .formStyle(.grouped)
  }
}

private struct WorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let effective = settings.effective(defaults: defaults)

    Form {
      Section {
        Toggle(
          "Override worktree path",
          isOn: overrides(\.worktreeDirectory, default: defaults.worktreeDirectory))
        TextField("Path:", text: text(\.worktreeDirectory, fallback: defaults.worktreeDirectory))
          .disabled(settings.worktreeDirectory == nil)
        SettingsCaption("Resolves to \(effective.worktreeContainer(for: project).path)")
      } footer: {
        SettingsCaption(
          settings.worktreeDirectory == nil
            ? "Using the global value, \(defaults.worktreeDirectory)."
            : "{project} is the repository folder name, ~ is home. Relative paths start at the repository."
        )
      }

      Section {
        Toggle(
          "Override branch prefix", isOn: overrides(\.branchPrefix, default: defaults.branchPrefix))
        TextField(
          "Prefix:", text: text(\.branchPrefix, fallback: defaults.branchPrefix),
          prompt: Text("none")
        )
        .disabled(settings.branchPrefix == nil)
        SettingsCaption(
          "Typing tabs creates \(effective.qualifiedBranch("tabs")) at \(effective.worktreePath(forBranch: effective.qualifiedBranch("tabs"), in: project).path)"
        )
      } footer: {
        if settings.branchPrefix == nil {
          SettingsCaption(
            defaults.branchPrefix.isEmpty
              ? "Using the global value: no prefix."
              : "Using the global value, \(defaults.branchPrefix).")
        } else if effective.branchPrefix.isEmpty {
          SettingsCaption("Overridden with no prefix, so the global one does not apply here.")
        }
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
    let source = setting(keyPath, of: project, in: model)
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
    let source = setting(keyPath, of: project, in: model)
    return Binding(
      get: { source.wrappedValue ?? fallback },
      set: { source.wrappedValue = $0 }
    )
  }
}

private struct HooksTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    Form {
      Section {
        TextField(
          "Post-create:", text: setting(\.postCreateHook, of: project, in: model),
          prompt: Text("npm install"), axis: .vertical
        )
        .lineLimit(2...4)
        SettingsCaption(
          "Runs in the new worktree after git worktree add. A failure is reported; the worktree stays."
        )
      }

      Section {
        TextField(
          "Post-delete:", text: setting(\.postDeleteHook, of: project, in: model),
          prompt: Text("Optional shell command"), axis: .vertical
        )
        .lineLimit(2...4)
        SettingsCaption(
          "Runs in the repository after git worktree remove, once the directory is gone.")
      }

      Section("Environment") {
        ForEach(Self.hookVariables, id: \.name) { variable in
          LabeledContent {
            Text(variable.meaning).foregroundStyle(.secondary)
          } label: {
            Text(variable.name).font(.system(size: 11, design: .monospaced))
          }
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
