import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellCore

@Suite @MainActor
struct WorkspaceStoreTests {
  @Test func addingTheSameProjectTwiceIsIdempotent() {
    let store = WorkspaceStore()
    store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    store.addProject(at: URL(fileURLWithPath: "/repos/demo/"))
    store.addProject(at: URL(fileURLWithPath: "/repos/other/../demo"))
    store.addProject(at: URL(fileURLWithPath: "/repos/./demo/"))
    #expect(store.workspace.projects.count == 1)
    #expect(store.workspace.projects[0].id == "/repos/demo")
  }

  /// Identity reads the stored path, so every way in must normalise it.
  @Test func everySpellingOfADirectoryGivesTheSameIdentity() throws {
    let spellings = ["/repos/demo", "/repos/demo/", "/repos/x/../demo", "/repos/./demo//"]
    let projects = spellings.map { Project(path: URL(fileURLWithPath: $0)) }
    #expect(Set(projects.map(\.id)) == ["/repos/demo"])
    let worktrees = spellings.map {
      Worktree(path: URL(fileURLWithPath: $0), projectID: "/p", head: "h")
    }
    #expect(Set(worktrees.map(\.id)) == ["/repos/demo"])

    let decoded = try JSONDecoder().decode(
      Project.self, from: Data(#"{ "path": "file:///repos/x/../demo" }"#.utf8))
    #expect(decoded.id == "/repos/demo")
  }

  @Test func removingAProjectDropsItsWorktreesTabsAndSessions() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    store.removeProject(project.id)

    #expect(store.workspace.projects.isEmpty)
    #expect(store.workspace.worktrees.isEmpty)
    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
  }

  @Test func refreshDropsTabsForWorktreesThatVanished() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    store.selectWorktree(worktree.id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
    #expect(store.workspace.selectedWorktreeID == nil)
  }

  @Test func aCustomNameIsTrimmedAndAnEmptyOneClearsIt() {
    let (store, _, worktree) = demoStore()
    store.setCustomName("  Checkout flow  ", forWorktree: worktree.id)
    #expect(store.workspace.customName(of: worktree.id) == "Checkout flow")
    #expect(store.workspace.displayName(of: worktree) == "Checkout flow")

    store.setCustomName("   ", forWorktree: worktree.id)
    #expect(store.workspace.worktreeNames.isEmpty, "a blank name is not a name")
    #expect(store.workspace.displayName(of: worktree) == "main", "the branch takes the row back")

    store.setCustomName("Later", forWorktree: worktree.id)
    store.setCustomName(nil, forWorktree: worktree.id)
    #expect(store.workspace.worktreeNames.isEmpty)
  }

  @Test func namingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, _) = demoStore()
    store.setCustomName("Ghost", forWorktree: "/repos/vanished")
    #expect(store.workspace.worktreeNames.isEmpty)
  }

  /// The name is the user's, but it belongs to a directory that no longer
  /// exists; leaving it would put it back on whatever is made there next.
  @Test func aRemovedWorktreeLeavesNoNameBehind() {
    let (store, project, worktree) = demoStore()
    store.setCustomName("Checkout flow", forWorktree: worktree.id)

    store.replaceWorktrees([], forProject: project.id)
    #expect(store.workspace.worktreeNames.isEmpty)

    store.replaceWorktrees([worktree], forProject: project.id)
    store.setCustomName("Checkout flow", forWorktree: worktree.id)
    store.removeProject(project.id)
    #expect(store.workspace.worktreeNames.isEmpty, "a removed project takes its names too")
  }

  @Test func closingTheActiveTabActivatesAnother() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!

    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)
    store.closeTab(second.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
  }

  @Test func aTabMovedToAnotherWorktreeTakesItsPanesAndLandsLast() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let settled = store.openTab(in: feature.id)!
    let moving = store.openTab(in: main.id)!
    store.splitFocusedPane(of: moving.id, axis: .vertical)

    #expect(store.moveTab(moving.id, to: feature.id))

    #expect(store.workspace.tab(moving.id)?.worktreeID == feature.id)
    #expect(store.workspace.tabs(in: feature.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.tabs(in: main.id).isEmpty)
    #expect(store.workspace.sessions(in: feature.id).count == 3, "both panes came along")
    #expect(store.workspace.sessions(in: main.id).isEmpty)
    #expect(store.workspace.activeTab(in: feature.id)?.id == moving.id)
  }

  /// The panes' shell is resolved from the worktree, so a tab left on the old directory
  /// would open one project's shell in another project's checkout on the next launch.
  @Test func aMovedTabsPanesStartInTheWorktreeItLandedIn() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let tab = store.openTab(in: main.id)!

    store.moveTab(tab.id, to: feature.id)

    #expect(store.workspace.session(tab.focusedSessionID)?.workingDirectory == feature.path)
  }

  @Test func theWorktreeATabLeavesFallsBackToItsLastTab() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let first = store.openTab(in: main.id)!
    let second = store.openTab(in: main.id)!

    store.moveTab(second.id, to: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == first.id)

    store.moveTab(first.id, to: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == nil, "no tabs, no active one")
  }

  @Test func aTabIsNotMovedToAWorktreeThatCannotTakeIt() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    #expect(store.moveTab(tab.id, to: "/repos/nowhere") == false)
    #expect(store.moveTab(tab.id, to: worktree.id) == false, "already there")
    #expect(store.moveTab(UUID(), to: worktree.id) == false, "no such tab")
    #expect(store.workspace.tab(tab.id)?.worktreeID == worktree.id)
  }

  @Test func sessionsInheritTheWorktreeDirectory() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let session = store.workspace.session(tab.focusedSessionID)
    #expect(session?.workingDirectory == worktree.path)
  }

  @Test func openingATabInAnUnknownWorktreeFails() {
    let store = WorkspaceStore()
    #expect(store.openTab(in: "/nowhere") == nil)
  }

  @Test func closingTheLastPaneClosesItsTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    store.closeSession(tab.focusedSessionID)

    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
  }

  @Test func closingOneSideOfASplitKeepsTheTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let original = tab.focusedSessionID
    let added = store.splitFocusedPane(of: tab.id, axis: .vertical)!

    store.closeSession(added.id)

    let survivor = store.workspace.tab(tab.id)
    #expect(survivor?.root == .terminal(original))
    #expect(survivor?.focusedSessionID == original)
    #expect(store.workspace.sessions.count == 1)
  }

  @Test func splittingAddsAPaneToTheSameTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)

    #expect(store.workspace.tabs.count == 1)
    #expect(store.workspace.tab(tab.id)?.sessionIDs.count == 2)
    #expect(store.workspace.tab(tab.id)?.isSplit == true)
  }

  /// The settings field writes on every keystroke, so the space between two
  /// flags has to survive being typed; only an empty line drops the entry.
  @Test func storingFlagsKeepsWhatWasTypedAndClearingRemovesTheEntry() {
    let store = WorkspaceStore()
    store.setAgentFlags("--model opus ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == "--model opus ")
    store.setAgentFlags(" ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == " ", "a space is a flag half typed")
    store.setAgentFlags("", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == nil, "cleared, so nothing is left behind")
  }
}
