import MultishellAppCore
import MultishellCore
import SwiftUI

/// Bindings for the settings forms. `Binding` is SwiftUI's, so these live in
/// the app rather than beside the model they read.
extension AppModel {
  /// A workspace value and the method that sets it, as one binding. The read
  /// goes through `workspace`, so the row follows a change made elsewhere.
  func setting<Value>(
    _ keyPath: KeyPath<Workspace, Value>, write: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { self.workspace[keyPath: keyPath] }, set: write)
  }

  /// The same where the stored value is optional and the control needs one:
  /// `fallback` is the id selected when nothing is stored.
  func setting<Value>(
    _ keyPath: KeyPath<Workspace, Value?>, or fallback: Value,
    write: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { self.workspace[keyPath: keyPath] ?? fallback }, set: write)
  }

  /// One agent's flag line. Not a key path, the stored value being a
  /// dictionary entry that reads as blank when absent.
  func agentFlagsSetting(for agentID: String) -> Binding<String> {
    Binding(
      get: { self.workspace.agentFlags[agentID] ?? "" },
      set: { self.setAgentFlags($0, for: agentID) })
  }

  /// The same for one project's own settings, written whole. The project is
  /// looked up again each time, a settings window outliving a refresh.
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

  /// Whether the project overrides `keyPath`, seeded with what the row was
  /// showing. Named well apart from `overrideValue`, which it type-matches.
  func hasOverride<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value?>, of project: Project, fallback: Value
  ) -> Binding<Bool> {
    let source = setting(keyPath, of: project)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? fallback : nil }
    )
  }

  /// The overridden value, reading as `fallback` while the override is off so
  /// the disabled control shows what is in effect.
  func overrideValue<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value?>, of project: Project, fallback: Value
  ) -> Binding<Value> {
    let source = setting(keyPath, of: project)
    return Binding(get: { source.wrappedValue ?? fallback }, set: { source.wrappedValue = $0 })
  }

  /// The record as the workspace has it now, falling back to the one the
  /// window was opened with, which goes stale across refreshes.
  func current(_ project: Project) -> Project {
    workspace.project(project.id) ?? project
  }

  /// The project's own settings, the repository's not layered in: these forms
  /// edit what the user set, and blank means "follow the global".
  func settings(of project: Project) -> ProjectSettings {
    current(project).settings
  }
}
