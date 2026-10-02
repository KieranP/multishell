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

  @Test func selectingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, worktree) = demoStore()
    store.selectWorktree(worktree.id)
    store.selectWorktree("/repos/vanished")
    #expect(store.workspace.selectedWorktreeID == worktree.id)
    store.selectWorktree(nil)
    #expect(store.workspace.selectedWorktreeID == nil)
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

  @Test func unknownIDsAreIgnored() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let before = store.workspace

    store.closeSession(UUID())
    store.closeTab(UUID())
    store.activateTab(UUID())
    store.setCustomTitle("x", forTab: UUID())
    store.setSplitWeights([1], at: [0], ofTab: UUID())

    #expect(store.workspace == before)
  }
}
