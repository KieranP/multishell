import MultishellAppCore
import MultishellCore
import SwiftUI

/// Bindings for the settings forms and the board's toggle. `Binding` is
/// SwiftUI's, so these live in the app rather than beside the model they read.
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

  /// One field of the global worktree defaults, the rest written back as
  /// they stand.
  func worktreeDefaultSetting(
    _ keyPath: WritableKeyPath<WorktreeSettings, String>
  ) -> Binding<String> {
    Binding(
      get: { self.workspace.worktreeDefaults[keyPath: keyPath] },
      set: { value in
        var defaults = self.workspace.worktreeDefaults
        defaults[keyPath: keyPath] = value
        self.setWorktreeDefaults(defaults)
      }
    )
  }

  /// Whether a state is announced, one toggle of the notification settings.
  func notificationSetting(for state: SessionState) -> Binding<Bool> {
    Binding(
      get: { self.workspace.notifications[state] },
      set: { on in
        var preference = self.workspace.notifications
        preference[state] = on
        self.setNotifications(preference)
      }
    )
  }

  /// The board's one filter, held by the model rather than the workspace.
  var showsAllTerminalsBinding: Binding<Bool> {
    Binding(get: { self.showsAllTerminals }, set: { self.setShowsAllTerminals($0) })
  }

  /// The same for one project's own settings, written whole. The project is
  /// looked up again each time, a settings window outliving a refresh.
  func setting<Value>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value>, of project: Project
  ) -> Binding<Value> {
    Binding(
      get: { self.ownSettings(of: project)[keyPath: keyPath] },
      set: { value in
        var settings = self.ownSettings(of: project)
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
}
