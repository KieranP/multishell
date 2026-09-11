import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct DebugPathsTests {
  /// Tests are debug builds, so they see the debug variant; a release build
  /// drops the suffix. Either way the three move together.
  ///
  /// Under a time limit because reading the variant walks up from the running
  /// binary looking for an `.app`, and a walk that does not end hangs the run
  /// rather than failing it: a job that times out after an hour says far less
  /// than this does.
  @Test(.timeLimit(.minutes(1)))
  func debugBuildsKeepTheirOwnStateSocketAndIntegration() {
    #expect(Paths.stateFile.lastPathComponent == "state\(Paths.variant).json")
    #expect(Paths.socketFile.lastPathComponent == "multishell\(Paths.variant).sock")
    #expect(Paths.integrationDirectory.lastPathComponent == "integration\(Paths.variant)")
    #expect(Paths.helperLink.lastPathComponent == "multishell", "shared: hooks reference it")
    #if DEBUG
      // A test process is no app bundle, so it carries no worktree name.
      #expect(Paths.variant == ".debug")
    #endif
  }

  /// A debug bundle built from a worktree gets its own state file, socket,
  /// integration directory and drops, so two worktrees can both `make run`.
  @Test func aWorktreesDebugBundleNamesItself() {
    #expect(Paths.debugVariant(named: "fix1") == ".debug-fix1")
    #expect(Paths.debugVariant(named: nil) == ".debug", "the checkout keeps the plain files")
    #expect(Paths.debugVariant(named: "") == ".debug", "make-app.sh writes the key empty")
  }

  /// The name lands in a socket path, and `sun_path` holds 104 bytes: this
  /// directory plus `multishell.debug-.sock` already spends about 75, so an
  /// uncut branch name would make the socket unbindable.
  @Test func aLongOrOddWorktreeNameIsCutAndSpelledSafely() {
    let longest = Paths.debugVariant(named: String(repeating: "\u{1F600}", count: 40))
    #expect(longest == ".debug-" + String(repeating: "-", count: 16))
    #expect(Paths.debugVariant(named: "feat.two words/x") == ".debug-feat-two-words-x")
    let socket =
      "/Users/averylongusername/Library/Application Support/Multishell"
      + "/multishell\(longest).sock"
    #expect(socket.utf8.count < 104, "\(socket.utf8.count) bytes: \(socket)")
  }
}

@Suite
struct PersistenceTests {
  private func scratchFile() -> URL {
    Scratch.path("state").appendingPathComponent("state.json")
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
        var group = TabGroup(worktreeID: worktree.id)
        for _ in 0..<10 {
          let a = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "a")
          let b = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "b")
          workspace.sessions += [a, b]
          workspace.tabs.append(
            TerminalTab(
              worktreeID: worktree.id, groupID: group.id,
              root: .split(axis: .horizontal, children: [.terminal(a.id), .terminal(b.id)]),
              focusedSessionID: a.id))
        }
        group.activeTabID = workspace.tabs.last?.id
        workspace.tabGroups.append(group)
        workspace.focusedGroupByWorktree[worktree.id] = group.id
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

    // Every scalar set away from its default, so a field the decoder forgets
    // to read fails here rather than silently reverting on someone's next
    // launch. The pairs that seed one field from another when the key is
    // absent (auto-start, opens-terminal) are set to differ from each other,
    // or a dropped key would read as the value it was meant to have.
    var workspace = Workspace()
    workspace.projects = [
      Project(
        path: URL(fileURLWithPath: "/repos/demo"), settings: ProjectSettings(branchPrefix: "k/"))
    ]
    workspace.worktreeNames = ["/repos/demo": "trunk"]
    workspace.terminalEngine = .swiftTerm
    workspace.appearance.themeID = "multishell.light"
    workspace.appearance.fontName = "Menlo"
    workspace.appearance.fontSize = 15
    workspace.appearance.uiFontSize = 16
    workspace.worktreeDefaults = WorktreeSettings(
      worktreeDirectory: "/trees", branchPrefix: "team/")
    workspace.notifications = NotificationPreference(attention: true, done: true)
    workspace.preferredAgentID = "claude"
    workspace.customAgentCommand = "my-agent --flag"
    workspace.agentFlags = ["claude": "--model haiku"]
    workspace.autoStartAgent = true
    workspace.autoStartAgentOnCreate = false
    workspace.defaultShell = "/opt/homebrew/bin/fish"
    workspace.customShellPath = "/usr/local/bin/zsh"
    workspace.preferredEditorID = "vscode"
    workspace.customEditorCommand = "edit {path}"
    workspace.opensTerminalOnSelect = false
    workspace.opensTerminalOnCreate = true
    workspace.worktreeSortOrder = .committedNewestFirst
    workspace.showsActiveWorktreesFirst = true
    workspace.confirmsWorktreeRemoval = false
    workspace.deletesBranchWithWorktree = true
    workspace.hookTimeoutSeconds = 5

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

    store.moveTab(t3.id, .before, t1.id)
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])

    store.moveTab(t1.id, .before, UUID())
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])

    // The trailing half of the last tab, which is the only way to the end
    // of the strip: there is no tab past it to land before.
    store.moveTab(t3.id, .after, t2.id)
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t1.id, t2.id, t3.id])
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
    let directory = Scratch.path("themes")
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
    let directory = Scratch.path("themes")
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
    let directory = Scratch.path("themes")
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
    let directory = Scratch.path("themes")
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
    let file = Scratch.path("scratch")
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
    #expect(store.workspace.activeTab(in: "/repos/demo")?.id == keptTab)
    WorkspaceInvariants.check(store.workspace, "restored")
    #expect(FileManager.default.fileExists(atPath: file.path), "nothing was moved aside")
  }
}

/// The other upgrade an existing install goes through: notifications were
/// one name, and are three toggles. Covered through the store rather than
/// only through `Codable`, since it is the file on disk that has to survive
/// the first launch and the first save after it.
@Suite @MainActor
struct NotificationPreferenceMigrationTests {
  @Test func thePickersLastRungComesBackAsThreeTogglesAndIsSavedThatWay() throws {
    let file = Scratch.path("scratch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(
      #"{ "projects": [ { "path": "file:///repos/demo/" } ], "notifications": "attentionAndDone" }"#
        .utf8
    ).write(to: file)

    let snapshot = WorkspaceSnapshot(fileURL: file)
    let (store, error) = WorkspaceStore.restored(from: snapshot)
    #expect(error == nil, "\(String(describing: error))")
    #expect(
      store.workspace.notifications
        == NotificationPreference(
          attention: true, error: true, done: true))

    try store.save()
    let written = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(
      written["notifications"] as? [String: Bool] == [
        "attention": true, "error": true, "done": true,
      ],
      "written as toggles, not as the name it was read from")

    let (again, reloadError) = WorkspaceStore.restored(from: snapshot)
    #expect(reloadError == nil, "\(String(describing: reloadError))")
    #expect(again.workspace.notifications == store.workspace.notifications)
  }
}

/// The upgrade every existing install goes through on its first launch: a
/// state file whose tabs name no column and whose active tab per worktree is
/// the key this build no longer has a property for.
@Suite @MainActor
struct TabGroupMigrationTests {
  @Test func aStateFileWrittenBeforeColumnsComesBackAsOneColumnPerWorktree() throws {
    let file = Scratch.path("scratch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

    let (shell, agent, left, right, lonely) = (UUID(), UUID(), UUID(), UUID(), UUID())
    let (shellTab, agentTab, splitTab, featureTab) = (UUID(), UUID(), UUID(), UUID())
    func session(_ id: UUID, _ worktree: String, _ title: String) -> String {
      """
      { "id": "\(id)", "worktreeID": "\(worktree)", "title": "\(title)",
        "workingDirectory": "file://\(worktree)/" }
      """
    }
    try Data(
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" },
          { "path": "file:///repos/demo-feat/", "projectID": "/repos/demo", "head": "b", "branch": "feat" } ],
        "sessions": [
          \#(session(shell, "/repos/demo", "zsh")),
          \#(session(agent, "/repos/demo", "claude")),
          \#(session(left, "/repos/demo", "left")),
          \#(session(right, "/repos/demo", "right")),
          \#(session(lonely, "/repos/demo-feat", "zsh")) ],
        "tabs": [
          { "id": "\#(shellTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(shell)",
            "root": { "terminal": { "_0": "\#(shell)" } } },
          { "id": "\#(agentTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(agent)",
            "customTitle": "build", "root": { "terminal": { "_0": "\#(agent)" } } },
          { "id": "\#(splitTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(right)",
            "root": { "split": { "axis": "horizontal", "weights": [3, 1], "children": [
              { "terminal": { "_0": "\#(left)" } }, { "terminal": { "_0": "\#(right)" } } ] } } },
          { "id": "\#(featureTab)", "worktreeID": "/repos/demo-feat", "focusedSessionID": "\#(lonely)",
            "root": { "terminal": { "_0": "\#(lonely)" } } } ],
        "activeTabByWorktree": { "/repos/demo": "\#(agentTab)" } }
      """#.utf8
    ).write(to: file)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    let ws = store.workspace

    #expect(error == nil, "\(String(describing: error))")
    WorkspaceInvariants.check(ws, "migrated")

    // One column per worktree, holding that worktree's tabs in file order.
    #expect(ws.groups(in: "/repos/demo").count == 1)
    #expect(ws.groups(in: "/repos/demo-feat").count == 1)
    let column = ws.groups(in: "/repos/demo")[0]
    #expect(ws.tabs(in: column.id).map(\.id) == [shellTab, agentTab, splitTab])

    // What the user was looking at, which is the whole reason the old key is
    // still read.
    #expect(ws.activeTab(in: "/repos/demo")?.id == agentTab)
    #expect(ws.activeTab(in: "/repos/demo-feat")?.id == featureTab, "its only tab")

    // Nothing else about the file was disturbed.
    #expect(ws.tab(agentTab)?.customTitle == "build")
    #expect(ws.tab(splitTab)?.isSplit == true)
    #expect(ws.tab(splitTab)?.focusedSessionID == right)
    #expect(ws.sessions.count == 5)
    #expect(ws.groups(in: "/repos/demo")[0].weight == 1)
  }

  /// The same file saved again names its columns, and the key it was read
  /// from is not written back.
  @Test func theMigratedStateIsWhatIsSavedFromThenOn() throws {
    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    let session = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
    var group = TabGroup(worktreeID: worktree.id)
    let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: session.id)
    group.activeTabID = tab.id
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [session]
    workspace.tabs = [tab]
    workspace.tabGroups = [group]
    workspace.focusedGroupByWorktree = [worktree.id: group.id]

    let json = String(decoding: try JSONEncoder().encode(workspace), as: UTF8.self)
    #expect(json.contains("tabGroups"))
    #expect(json.contains("focusedGroupByWorktree"))
    #expect(!json.contains("activeTabByWorktree"), "the old key is read, never written")

    var reloaded = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
    reloaded.repairReferences()
    #expect(reloaded == workspace, "a saved layout comes back exactly")
  }
}
