import AppKit
import MultishellCore
import Testing

@testable import Multishell

/// A watcher that records what it was asked to watch and can be poked.
@MainActor
private final class FakeWatcher: DirectoryWatcher {
  var onChange: (@MainActor () -> Void)?
  var watched: [URL] = []
  var stopped = false
  func watch(_ directories: [URL]) { watched = directories }
  func stop() { stopped = true }
}

/// An engine that opens everything and remembers focus and closes.
@MainActor
private final class FakeEngine: TerminalSurfaceHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var focused: [TerminalSession.ID] = []
  var closed: [TerminalSession.ID] = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws { openSessionIDs.insert(session.id) }
  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    closed.append(id)
  }
  func focus(_ id: TerminalSession.ID) { focused.append(id) }
  func view(for id: TerminalSession.ID) -> NSView? { nil }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

@MainActor
private struct Harness {
  let model: AppModel
  let store: WorkspaceStore
  let engine = FakeEngine()
  let watcher = FakeWatcher()
  let project: Project
  let main: Worktree
  let feature: Worktree

  init(savedSelection: Bool = false, stateFile: URL? = nil) {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-appmodel-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(
        fileURL: stateFile ?? tmp.appendingPathComponent("state.json")))
    project = store.addProject(at: tmp)  // exists on disk, so `select` accepts it
    main = Worktree(path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    feature = Worktree(
      path: tmp.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    try? FileManager.default.createDirectory(at: feature.path, withIntermediateDirectories: true)
    store.replaceWorktrees([main, feature], forProject: project.id)
    if savedSelection { store.selectWorktree(main.id) }

    let engine = self.engine
    let host = MultiEngineHost(engine: .ghostty) { _ in engine }
    model = AppModel(store: store, host: host, worktrees: nil, watcher: watcher)
  }
}

@Suite @MainActor
struct AppModelTests {
  @Test func launchStartsWithNothingSelectedAndNoShells() {
    let h = Harness(savedSelection: true)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.liveTerminalCount == 0)
    #expect(
      h.model.presentedError?.title == "git not found", "no git was injected, and that is reported")
  }

  @Test func selectingAWorktreeOpensATabAndWarmsIt() {
    let h = Harness()
    h.model.select(h.main)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.focused.count == 1)
    #expect(h.model.liveSessions == h.engine.openSessionIDs)
  }

  @Test func savedTabsInAnUnvisitedWorktreeStayCold() {
    let h = Harness()
    h.store.openTab(in: h.feature.id)
    h.store.openTab(in: h.feature.id)
    h.model.select(h.main)

    #expect(h.model.workspace.sessions.count == 3)
    #expect(h.model.liveTerminalCount == 1, "only the selected worktree's shell is live")

    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 3, "visiting warms the saved tabs, and main stays warm")
  }

  @Test func selectingAWorktreeWhoseDirectoryIsGoneIsRefused() {
    let h = Harness()
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: h.project.id,
      head: "c", branch: "ghost")
    h.store.replaceWorktrees([h.main, h.feature, ghost], forProject: h.project.id)
    h.model.presentedError = nil

    h.model.select(ghost)

    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func closingTheLastPaneClosesItsTabAndShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 2)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.engine.closed.count == 1)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)

    h.model.closeActivePane()  // nothing left: must not throw or select anything
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }

  @Test func splitThenCloseCollapsesBackToOnePane() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.isSplit && h.model.liveTerminalCount == 2)

    h.model.closeActivePane()
    let after = h.model.workspace.tab(tab.id)!
    #expect(!after.isSplit)
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func removalAsksUnlessTheProjectOptedOut() {
    let h = Harness()
    h.model.requestRemoval(of: h.feature)
    #expect(h.model.pendingRemoval?.id == h.feature.id)

    h.model.pendingRemoval = nil
    h.model.updateSettings(ProjectSettings(confirmsWorktreeRemoval: false), for: h.project)
    h.model.requestRemoval(of: h.feature)
    #expect(
      h.model.pendingRemoval == nil, "goes straight to removal, which needs git and so no-ops here")
  }

  @Test func activityInABackgroundTabIsRememberedUntilItIsShown() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: second.focusedSessionID)

    #expect(h.model.hasUnseenActivity(first))
    #expect(!h.model.hasUnseenActivity(second), "the focused tab is being watched")
    #expect(h.model.unseenActivityCount(in: h.main.id) == 1)

    h.model.activate(first)
    #expect(!h.model.hasUnseenActivity(first))
  }

  @Test func aBurstOfActivityCoalescesIntoOneStatusRefresh() async {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    // Title before the command, command finished, title after: what one
    // prompt produces. Each used to spawn its own `git status`.
    for _ in 0..<3 {
      h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "make")
      h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: tab.focusedSessionID)
    }

    #expect(h.model.pendingStatusRefreshes.count == 1)
    #expect(h.model.pendingStatusRefreshes[h.main.id] != nil)

    // The debounce is 250 ms; the margin is for a busy CI runner's timers.
    try? await Task.sleep(for: .seconds(1))
    #expect(h.model.pendingStatusRefreshes.isEmpty, "the one refresh ran and cleared itself")
  }

  @Test func activityOfAShellThatExitedIsForgotten() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.unseenActivityCount(in: h.main.id) == 1)

    h.engine.delegate?.terminalHost(h.engine, didExit: first.focusedSessionID, code: 0)

    #expect(h.model.unseenActivity.isEmpty, "nothing left to look at")
  }

  @Test func aProcessExitDropsTheTabAndTheLiveCount() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID, code: 0)

    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func switchingEngineAffectsOnlyNewTabs() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setTerminalEngine(.swiftTerm)
    #expect(h.model.workspace.terminalEngine == .swiftTerm)
    #expect(h.model.host.engine == .swiftTerm)
    #expect(h.model.liveTerminalCount == 1, "the running shell was not restarted")
  }

  @Test func activeProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(h.model.activeProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.activeProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.activeProject?.id == h.project.id)
  }

  @Test func shellTitlesAreShownButNeverWrittenToTheWorkspace() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let before = h.model.workspace

    h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "vim")
    #expect(h.model.title(of: tab) == "vim")
    #expect(h.model.workspace == before, "a prompt must not trigger a save")

    h.model.renameTab(tab.id, to: "build")
    #expect(h.model.title(of: h.model.workspace.tab(tab.id)!) == "build")
    h.model.renameTab(tab.id, to: nil)
    #expect(h.model.title(of: h.model.workspace.tab(tab.id)!) == "vim")

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID, code: 0)
    #expect(h.model.sessionTitles.isEmpty, "titles of dead shells are not kept")
  }

  @Test func aFailingSaveIsReportedOnceNotAfterEveryChange() {
    // A file where a directory is needed: nothing can be created under it.
    let h = Harness(stateFile: URL(fileURLWithPath: "/dev/null/multishell/state.json"))
    h.model.presentedError = nil

    h.model.save()
    let first = h.model.presentedError
    #expect(first != nil)

    h.model.save()
    h.model.save()
    #expect(h.model.presentedError?.id == first?.id, "the same alert, not a new one each time")
  }

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, before: a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])
  }
}

/// Deterministic, so a failing sequence can be replayed from its seed.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

/// Random user actions and engine events, in any order. After each, what the
/// views read must agree with what the engine has: the same live set, every
/// live shell backed by a session, no title or dot for a shell that is gone,
/// and the focused pane of the shown tab is what the engine was told to
/// focus last.
@Suite @MainActor
struct AppModelInvariantTests {
  @Test(arguments: [3, 4, 6, 9, 12, 17, 25, 33] as [UInt64])
  func anySequenceOfActionsAndEventsKeepsTheRuntimeConsistent(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    let h = Harness()
    let worktrees = [h.main, h.feature]

    for step in 0..<300 {
      let ws = h.model.workspace
      let live = Array(h.engine.openSessionIDs)
      switch Int.random(in: 0..<12, using: &rng) {
      case 0, 1: h.model.select(worktrees.randomElement(using: &rng)!)
      case 2: h.model.newTab()
      case 3: h.model.closeActivePane()
      case 4: h.model.closeActiveTab()
      case 5: h.model.splitActivePane(Bool.random(using: &rng) ? .horizontal : .vertical)
      case 6: if let tab = ws.tabs.randomElement(using: &rng) { h.model.activate(tab) }
      case 7: Bool.random(using: &rng) ? h.model.selectNextTab() : h.model.selectPreviousTab()
      case 8:
        if let id = live.randomElement(using: &rng) {
          h.engine.delegate?.terminalHost(h.engine, didExit: id, code: 0)
        }
      case 9:
        if let id = live.randomElement(using: &rng) {
          h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: id)
          h.engine.delegate?.terminalHost(h.engine, didRetitle: id, to: "t\(step)")
        }
      case 10:
        // A click lands only on a visible pane, and the click itself gives
        // the surface focus, which the fake records as if `focus` had.
        if let selected = ws.selectedWorktreeID, let shown = ws.activeTab(in: selected),
          let id = shown.sessionIDs.randomElement(using: &rng)
        {
          h.engine.focused.append(id)
          h.engine.delegate?.terminalHost(h.engine, didFocus: id)
        }
      default:
        // A refresh that lost or found a worktree, then the sync every
        // model action ends with.
        let kept = worktrees.filter { _ in Bool.random(using: &rng) }
        h.store.replaceWorktrees(kept.isEmpty ? worktrees : kept, forProject: h.project.id)
        h.model.sync()
      }
      check(h, "seed \(seed) step \(step)")
    }
  }

  private func check(_ h: Harness, _ context: String) {
    let ws = h.model.workspace
    let live = h.engine.openSessionIDs
    let sessionIDs = Set(ws.sessions.map(\.id))

    #expect(h.model.liveSessions == live, "\(context): views see a different live set")
    #expect(live.isSubset(of: sessionIDs), "\(context): a shell with no session")
    #expect(Set(h.model.sessionTitles.keys).isSubset(of: live), "\(context): title of a dead shell")
    #expect(h.model.unseenActivity.isSubset(of: live), "\(context): dot for a dead shell")
    #expect(h.model.liveTerminalCount == live.count, "\(context): quit guard count")

    // Every session of a visited worktree has a shell; unvisited ones none.
    for session in ws.sessions {
      let warm = h.model.warmWorktrees.contains(session.worktreeID)
      #expect(live.contains(session.id) == warm, "\(context): warmth and liveness disagree")
    }

    if let selected = ws.selectedWorktreeID, let tab = ws.activeTab(in: selected) {
      #expect(
        h.engine.focused.last == tab.focusedSessionID,
        "\(context): engine focus is not the shown pane")
    }
    for tab in ws.tabs {
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      #expect(tab.sessionIDs.allSatisfy(sessionIDs.contains), "\(context): pane without a session")
    }
  }
}
