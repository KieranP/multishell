import Foundation
import Testing

@testable import MultishellCore

@Suite
struct PersistenceTests {
  private func scratchFile() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("state.json")
  }

  @Test func stateWrittenBeforeAFieldExistedStillLoads() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Only what the very first build wrote: no appearance, no engine, no tabs.
    try Data(
      """
      { "projects": [ { "path": "file:///repos/demo/" } ], "worktrees": [], "sessions": [] }
      """.utf8
    ).write(to: file)

    let workspace = try WorkspaceSnapshot(fileURL: file).load()

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.terminalEngine == .ghostty)
    #expect(workspace.appearance.themeID == Theme.multishellDark.id)
  }

  @Test func unreadableStateIsMovedAsideNotOverwritten() throws {
    let file = scratchFile()
    let directory = file.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: file)

    let snapshot = WorkspaceSnapshot(fileURL: file)
    #expect(throws: UnreadableState.self) { try snapshot.load() }

    let survivors = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(survivors.contains { $0.hasSuffix(".broken.json") })
    #expect(
      try String(contentsOf: directory.appendingPathComponent(survivors[0]), encoding: .utf8)
        == "not json")
  }

  @Test func roundTripPreservesEverything() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    var workspace = Workspace()
    workspace.projects = [
      Project(
        path: URL(fileURLWithPath: "/repos/demo"), settings: ProjectSettings(branchPrefix: "k/"))
    ]
    workspace.terminalEngine = .swiftTerm
    workspace.appearance.fontSize = 15

    let snapshot = WorkspaceSnapshot(fileURL: file)
    try snapshot.save(workspace)
    #expect(try snapshot.load() == workspace)
  }
}

@Suite @MainActor
struct OrderingTests {
  private func store() -> (WorkspaceStore, Worktree) {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    store.addProject(at: URL(fileURLWithPath: "/repos/c"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "x", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    return (store, worktree)
  }

  @Test func projectsMoveLikeSwiftUIExpects() {
    let (store, _) = store()
    store.moveProjects(from: IndexSet(integer: 0), to: 3)
    #expect(store.workspace.projects.map(\.name) == ["b", "c", "a"])
    store.moveProjects(from: IndexSet(integer: 2), to: 0)
    #expect(store.workspace.projects.map(\.name) == ["a", "b", "c"])
  }

  @Test func tabsMoveWithinTheirWorktreeOnly() {
    let (store, worktree) = store()
    let t1 = store.openTab(in: worktree.id)!
    let t2 = store.openTab(in: worktree.id)!
    let t3 = store.openTab(in: worktree.id)!

    store.moveTab(t3.id, before: t1.id)
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])

    store.moveTab(t1.id, before: UUID())
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])
  }

  @Test func nextAndPreviousWrapAround() {
    let (store, worktree) = store()
    let t1 = store.openTab(in: worktree.id)!
    let t2 = store.openTab(in: worktree.id)!

    #expect(store.workspace.tab(after: t2.id)?.id == t1.id)
    #expect(store.workspace.tab(before: t1.id)?.id == t2.id)
    store.closeTab(t2.id)
    #expect(store.workspace.tab(after: t1.id) == nil)
  }
}

@Suite
struct ThemeCatalogTests {
  @Test func userFilesAreAddedAndCanReplaceBuiltins() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-themes-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var custom = Theme.multishellDark
    custom.id = "user.custom"
    custom.name = "Custom"
    var override = Theme.multishellLight
    override.name = "Light, but mine"
    for theme in [custom, override] {
      try JSONEncoder().encode(theme).write(
        to: directory.appendingPathComponent("\(theme.id).json"))
    }
    try Data("{".utf8).write(to: directory.appendingPathComponent("broken.json"))

    let catalogue = ThemeCatalog.load(from: directory)

    #expect(catalogue.themes.map(\.id) == ["multishell.dark", "multishell.light", "user.custom"])
    #expect(catalogue.themes.first { $0.id == Theme.multishellLight.id }?.name == "Light, but mine")
    #expect(catalogue.problems.count == 1)
  }

  @Test func loadAloneRelocatesStrayExamples() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-themes-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(Theme.multishellDark).write(
      to: directory.appendingPathComponent("example.multishell.dark.json"))

    let catalogue = ThemeCatalog.load(from: directory)

    #expect(catalogue.themes.count == Theme.builtins.count)
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("examples/example.multishell.dark.json").path))
  }

  @Test func examplesAreWrittenBesideTheThemesNotAmongThem() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-themes-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // A leftover from the earlier layout, which loaded as a duplicate.
    try JSONEncoder().encode(Theme.multishellDark).write(
      to: directory.appendingPathComponent("example.multishell.dark.json"))

    try ThemeCatalog.seedExamples(in: directory)

    #expect(ThemeCatalog.load(from: directory).themes.map(\.id) == Theme.builtins.map(\.id))
    let examples = try FileManager.default.contentsOfDirectory(
      atPath: directory.appendingPathComponent("examples").path
    ).sorted()
    #expect(
      examples == ["example.multishell.dark.json", "multishell.dark.json", "multishell.light.json"])
  }
}
