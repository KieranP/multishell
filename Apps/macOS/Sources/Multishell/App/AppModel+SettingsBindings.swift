import MultishellAppCore
import MultishellCore
import SwiftUI

/// Bindings for the settings forms, where every row reads a stored value
/// and writes it through a model method. `Binding` is SwiftUI's, so these
/// live in the app rather than beside the model they read.
extension AppModel {
  /// A workspace value and the method that sets it, as one binding:
  /// `model.setting(\.autoStartAgent, write: model.setAutoStartAgent)`. The
  /// read goes through `workspace` each time, so the row follows a change
  /// made anywhere else.
  func setting<Value>(
    _ keyPath: KeyPath<Workspace, Value>, write: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { self.workspace[keyPath: keyPath] }, set: write)
  }

  /// The same where the stored value is optional and the control needs a
  /// value: a detection picker's list carries a row for "none" or "login
  /// shell", and `fallback` is the id it selects when nothing is stored.
  /// The setter maps that id back to `nil`, so it takes the id, not the
  /// optional.
  func setting<Value>(
    _ keyPath: KeyPath<Workspace, Value?>, or fallback: Value,
    write: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { self.workspace[keyPath: keyPath] ?? fallback }, set: write)
  }

  /// The same for one project's own settings, which are written as a whole
  /// value. The project is looked up again on every read and write: a
  /// settings window outlives the refresh that replaced the record it was
  /// opened with.
  func setting<Value>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value>, of project: Project
  ) -> Binding<Value> {
    Binding(
      get: { self.settings(of: project)[keyPath: keyPath] },
      set: { value in
        var settings = self.settings(of: project)
        settings[keyPath: keyPath] = value
        self.updateSettings(settings, for: project)
      }
    )
  }

  /// The record as the workspace has it now, falling back to the one the
  /// window was opened with. A settings window is its own scene and stays
  /// up across refreshes, so the project it was handed goes stale.
  func current(_ project: Project) -> Project {
    workspace.project(project.id) ?? project
  }

  /// The project's own settings, the repository's not layered in: these
  /// forms edit what the user set, and a blank field means "follow the
  /// global" rather than "override with nothing".
  func settings(of project: Project) -> ProjectSettings {
    current(project).settings
  }
}
