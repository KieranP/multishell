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

  /// One agent's flag line. Not a key path: the stored value is a
  /// dictionary entry, and an agent with nothing stored reads as blank
  /// rather than as an absent row.
  func agentFlagsSetting(for agentID: String) -> Binding<String> {
    Binding(
      get: { self.workspace.agentFlags[agentID] ?? "" },
      set: { self.setAgentFlags($0, for: agentID) })
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

  /// Whether the project overrides `keyPath` at all, for the toggle above
  /// the row. Turning it on seeds the override with `fallback`, so nothing
  /// the user was looking at changes as the toggle flips; turning it off
  /// goes back to following it.
  ///
  /// Pass what the row was actually showing, which is what
  /// `model.inherited(_:global:for:)` answers where a repository's
  /// `.multishell.json` may have had the say. Seeding from the global
  /// instead would replace what the project was doing with a value nobody
  /// was using.
  ///
  /// Named well apart from `overrideValue`: for a `Bool` setting both give a
  /// `Binding<Bool>` from the same arguments, so a swapped pair would
  /// compile and quietly bind each control to the other's job.
  func hasOverride<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value?>, of project: Project, fallback: Value
  ) -> Binding<Bool> {
    let source = setting(keyPath, of: project)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? fallback : nil }
    )
  }

  /// The overridden value itself, reading as `fallback` while the override
  /// is off so the disabled control shows what is actually in effect rather
  /// than blank.
  func overrideValue<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value?>, of project: Project, fallback: Value
  ) -> Binding<Value> {
    let source = setting(keyPath, of: project)
    return Binding(get: { source.wrappedValue ?? fallback }, set: { source.wrappedValue = $0 })
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
