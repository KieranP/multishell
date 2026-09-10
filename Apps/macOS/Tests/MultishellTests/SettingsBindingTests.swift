import AppKit
import MultishellAppCore
import MultishellCore
import Testing

@testable import Multishell

/// The bindings a project settings row is built from.
///
/// `hasOverride` and `overrideValue` are the hazard their own doc comment
/// names: for a `Bool` setting both return a `Binding<Bool>` from the same
/// arguments, so a swapped pair compiles and quietly binds each control to
/// the other's job. Nothing above them can catch that — the form is a view,
/// and views are not tested — so it is caught here, where the bindings are
/// driven the way a toggle and a field drive them and the store is read back.
@Suite @MainActor
struct SettingsBindingTests {
  /// Turning an override on stores the value that was already in force, not
  /// `true`. This is the assertion a swapped pair fails: bound to
  /// `overrideValue`, the toggle would write its own `true` into the
  /// setting, and the project would start auto-starting an agent because
  /// someone ticked "override".
  @Test func turningAnOverrideOnSeedsItWithWhatWasInForce() {
    let harness = BindingHarness()
    let project = harness.project
    #expect(harness.model.workspace.autoStartAgent == false, "the global this inherits from")

    let toggle = harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false)
    #expect(toggle.wrappedValue == false, "no override yet")

    toggle.wrappedValue = true
    #expect(
      harness.settings(of: project).autoStartAgent == false,
      "seeded with the inherited false, not with the toggle's own true")
    #expect(
      harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false).wrappedValue,
      "and the row now reads as overridden")
  }

  /// Turning it off goes back to following, rather than storing the value
  /// the disabled control happened to be showing.
  @Test func turningAnOverrideOffClearsItRatherThanStoringWhatWasShown() {
    let harness = BindingHarness()
    let project = harness.project
    harness.model.overrideValue(\.autoStartAgent, of: project, fallback: false).wrappedValue = true
    #expect(harness.settings(of: project).autoStartAgent == true)

    harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false).wrappedValue = false
    #expect(
      harness.settings(of: project).autoStartAgent == nil,
      "off means follow the global, which is a nil override and not a stored false")
  }

  /// The disabled control shows what is actually in effect. Blank would
  /// read as "this project has no worktree path", which is a different
  /// claim from "it uses the one you set globally".
  @Test func anOverrideThatIsOffShowsTheInheritedValue() {
    let harness = BindingHarness()
    let project = harness.project

    let field = harness.model.overrideValue(
      \.worktreeDirectory, of: project, fallback: "../inherited-worktrees")
    #expect(field.wrappedValue == "../inherited-worktrees")
    #expect(
      harness.settings(of: project).worktreeDirectory == nil,
      "reading the row stores nothing, so the project still follows")

    field.wrappedValue = "../its-own"
    #expect(harness.settings(of: project).worktreeDirectory == "../its-own")
  }

  /// A blank override is a value, not an absence: it is how "no prefix" is
  /// spelled while the global has one. The pair has to keep them apart.
  @Test func aBlankOverrideStaysAnOverride() {
    let harness = BindingHarness()
    let project = harness.project
    harness.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))

    let field = harness.model.overrideValue(\.branchPrefix, of: project, fallback: "team/")
    field.wrappedValue = ""
    #expect(harness.settings(of: project).branchPrefix == "")
    #expect(
      harness.model.hasOverride(\.branchPrefix, of: project, fallback: "team/").wrappedValue,
      "blank is still the project having its say")
    #expect(
      harness.model.worktreeSettings(for: harness.model.current(project))
        .qualifiedBranch("tabs") == "tabs",
      "and the branch it would create carries no prefix")
  }

  /// A settings window is its own scene and stays up across refreshes, so
  /// the `Project` it was handed goes stale. Every read and write looks the
  /// record up again; a binding that closed over the old one would write
  /// its settings back over anything changed meanwhile.
  @Test func aBindingFollowsTheRecordAndNotTheProjectItWasBuiltWith() {
    let harness = BindingHarness()
    let stale = harness.project

    // Something else changes the project while the window holds `stale`.
    harness.model.setExpanded(false, for: stale)
    harness.model.overrideValue(\.autoStartAgent, of: stale, fallback: false).wrappedValue = true

    #expect(harness.model.current(stale).isExpanded == false, "the change is not lost")
    #expect(harness.settings(of: stale).autoStartAgent == true, "and the write still landed")
  }
}

/// The Mac model with nothing behind it: no git, no watcher, no engine.
/// These tests only read and write settings, so none of the three is ever
/// reached.
@MainActor
private struct BindingHarness {
  let model: Multishell.AppModel
  let project: Project

  init() {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-bindings-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: directory.appendingPathComponent("state.json")))
    project = store.addProject(at: directory)
    let engine = NoEngine()
    model = AppModel(
      store: store,
      host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: nil,
      watcher: NoWatcher())
  }

  /// The project's own settings, the repository's not layered in, which is
  /// what these forms edit.
  func settings(of project: Project) -> ProjectSettings {
    model.settings(of: project)
  }
}

@MainActor
private final class NoEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws {}
  func close(_ id: TerminalSession.ID) {}
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { false }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

@MainActor
private final class NoWatcher: DirectoryWatcher {
  var onChange: (@MainActor () -> Void)?
  func watch(_ directories: [URL]) {}
  func stop() {}
}
