import Foundation
import Testing

@testable import MultishellCore

@Suite
struct DebugPathsTests {
  /// Tests are debug builds, so they see the debug variant; a release build
  /// drops the suffix. Either way the three move together.
  @Test func debugBuildsKeepTheirOwnStateSocketAndIntegration() {
    #expect(Paths.stateFile.lastPathComponent == "state\(Paths.variant).json")
    #expect(Paths.socketFile.lastPathComponent == "multishell\(Paths.variant).sock")
    #expect(Paths.integrationDirectory.lastPathComponent == "integration\(Paths.variant)")
    #expect(Paths.helperLink.lastPathComponent == "multishell", "shared: hooks reference it")
    #if DEBUG
      #expect(Paths.variant == ".debug")
    #endif
  }
}

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
    var reported: URL?
    do {
      _ = try snapshot.load()
      Issue.record("unreadable state loaded")
    } catch let state as UnreadableState {
      reported = state.backup
    }

    let survivors = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(survivors.contains { $0.hasSuffix(".broken.json") })
    #expect(
      FileManager.default.fileExists(atPath: reported?.path ?? ""),
      "the alert names the backup, so it must be the file that was written")
    #expect(
      try String(contentsOf: directory.appendingPathComponent(survivors[0]), encoding: .utf8)
        == "not json")
  }

  @Test @MainActor func restoringRepairsDanglingReferencesBeforeTheStoreSeesThem() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    workspace.projects = [project]
    workspace.worktrees = [
      worktree,
      Worktree(path: URL(fileURLWithPath: "/repos/orphan"), projectID: "/repos/gone", head: "b"),
    ]
    let orphan = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "x")
    workspace.sessions = [orphan]
    try WorkspaceSnapshot(fileURL: file).save(workspace)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))

    #expect(error == nil)
    #expect(store.workspace.worktrees.map(\.id) == [worktree.id])
    #expect(
      store.workspace.sessions.isEmpty,
      "a session no tab shows would get a shell nobody can close")
  }

  /// Autosave encodes and writes on the main thread after every change. A
  /// workspace far larger than anyone keeps must still save in a blink.
  @Test func aLargeWorkspaceSavesAndLoadsQuickly() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    var workspace = Workspace()
    for p in 0..<20 {
      let project = Project(path: URL(fileURLWithPath: "/repos/p\(p)"))
      workspace.projects.append(project)
      for w in 0..<10 {
        let worktree = Worktree(
          path: URL(fileURLWithPath: "/repos/p\(p)-trees/w\(w)"), projectID: project.id,
          head: "abc", branch: "w\(w)")
        workspace.worktrees.append(worktree)
        for _ in 0..<10 {
          let a = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "a")
          let b = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "b")
          workspace.sessions += [a, b]
          workspace.tabs.append(
            TerminalTab(
              worktreeID: worktree.id,
              root: .split(axis: .horizontal, children: [.terminal(a.id), .terminal(b.id)]),
              focusedSessionID: a.id))
        }
      }
    }
    #expect(workspace.tabs.count == 2000)

    let snapshot = WorkspaceSnapshot(fileURL: file)
    let saving = ContinuousClock.now
    try snapshot.save(workspace)
    let saved = ContinuousClock.now - saving
    let loading = ContinuousClock.now
    let loaded = try snapshot.load()
    let loadTime = ContinuousClock.now - loading

    #expect(loaded == workspace)
    // Locally each is a few tens of ms. The bounds are far above that
    // because these are wall-clock readings taken while the rest of the
    // suite runs beside them on a two-core runner; what they catch is an
    // accidental quadratic, which costs minutes, not a doubling.
    #expect(saved < .seconds(5), "save took \(saved)")
    #expect(loadTime < .seconds(5), "load took \(loadTime)")

    // Every launch repairs what it loaded, on the main thread, before the
    // window appears.
    var repaired = loaded
    let repairing = ContinuousClock.now
    repaired.repairReferences()
    let repairTime = ContinuousClock.now - repairing
    #expect(repaired == loaded, "a sound workspace is left alone")
    #expect(repairTime < .seconds(5), "repair took \(repairTime)")
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

  @Test func aMoveOutsideTheListIsIgnoredNotACrash() {
    let (store, _) = store()
    store.moveProjects(from: IndexSet(integer: 0), to: 4)
    store.moveProjects(from: IndexSet(integer: 7), to: 0)
    store.moveProjects(from: IndexSet(integer: 1), to: -1)
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

  @Test func aThemeFileWithTooFewColoursIsAProblemNotACrash() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-themes-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var short = Theme.multishellDark
    short.id = "user.short"
    short.ansi = Array(short.ansi.prefix(8))
    try JSONEncoder().encode(short).write(to: directory.appendingPathComponent("short.json"))

    let catalogue = ThemeCatalog.load(from: directory)

    #expect(catalogue.themes.map(\.id) == Theme.builtins.map(\.id))
    #expect(catalogue.problems.count == 1)
    #expect(catalogue.problems[0].hasPrefix("short.json:"))
    #expect(catalogue.themes.allSatisfy { $0.ansiRGB.count == 16 })
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

@Suite @MainActor
struct PartialStateTests {
  /// A tab whose pane kind this build does not know, next to a sound one:
  /// the store must come up with the project, the sound tab and no error,
  /// and the session the dropped tab owned must go with it.
  @Test func aStateFileWithOneUnreadableTabRestoresEverythingElse() throws {
    let file = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

    let kept = UUID()
    let orphaned = UUID()
    let keptTab = UUID()
    try Data(
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [ { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a" } ],
        "sessions": [
          { "id": "\#(kept)", "worktreeID": "/repos/demo", "workingDirectory": "file:///repos/demo/", "title": "sh" },
          { "id": "\#(orphaned)", "worktreeID": "/repos/demo", "workingDirectory": "file:///repos/demo/", "title": "sh" } ],
        "tabs": [
          { "id": "\#(keptTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(kept)",
            "root": { "terminal": { "_0": "\#(kept)" } } },
          { "id": "\#(UUID())", "worktreeID": "/repos/demo", "focusedSessionID": "\#(orphaned)",
            "root": { "stack": { "pages": [ { "terminal": { "_0": "\#(orphaned)" } } ] } } } ],
        "activeTabByWorktree": { "/repos/demo": "\#(keptTab)" } }
      """#.utf8
    ).write(to: file)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))

    #expect(error == nil, "\(String(describing: error))")
    #expect(store.workspace.projects.map(\.name) == ["demo"])
    #expect(store.workspace.tabs.map(\.id) == [keptTab])
    #expect(store.workspace.sessions.map(\.id) == [kept])
    #expect(store.workspace.activeTabByWorktree["/repos/demo"] == keptTab)
    WorkspaceInvariants.check(store.workspace, "restored")
    #expect(FileManager.default.fileExists(atPath: file.path), "nothing was moved aside")
  }
}
