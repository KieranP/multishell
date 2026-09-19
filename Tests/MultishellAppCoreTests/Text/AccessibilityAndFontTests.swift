import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Testing

@testable import MultishellAppCore

/// What a screen reader says for the hand-drawn rows and tabs.
@Suite
struct AccessibilityTextTests {
  private let feature = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"), projectID: "/r", head: "abc", branch: "feat")

  private let now = Date(timeIntervalSince1970: 1_000_000)

  private func card(
    occupant: AgentBoardCard.Occupant, state: SessionState?, secondsAgo: Double? = nil,
    note: SessionNote? = nil, status: WorktreeStatus? = nil
  ) -> AgentBoardCard {
    AgentBoardCard(
      id: UUID(), tabID: UUID(), worktreeID: "/r", occupant: occupant,
      title: "claude — repairReferences", projectName: "multishell", worktreeName: "agents-view",
      state: state, since: secondsAgo.map { now.addingTimeInterval(-$0) }, note: note,
      status: status)
  }

  @Test func aBoardCardReadsInTheOrderItIsDrawn() {
    var status = WorktreeStatus()
    status.unstaged = 3
    status.changedFiles = 3
    #expect(
      AccessibilityText.card(
        card(
          occupant: .agent(id: "claude", name: "Claude Code"), state: .attention, secondsAgo: 360,
          note: SessionNote(state: .attention, message: "Permission to run rm -rf .build"),
          status: status),
        at: now)
          == """
          Waiting for input, multishell, agents-view, +0 −0 · 3 modified, \
          claude — repairReferences, Claude Code, agent, for 6m, \
          Permission to run rm -rf .build
          """)

    // A shell says so, and a pane with nothing to report says the idle
    // wording rather than nothing at all.
    #expect(
      AccessibilityText.card(card(occupant: .shell("zsh"), state: nil), at: now)
        == "Nothing running, multishell, agents-view, claude — repairReferences, zsh, shell",
      "no time to give, and nothing said")
  }

  @Test func theAgentsRowReadsItsCounts() {
    #expect(
      AccessibilityText.agentsRow([(.waiting, 2), (.working, 3), (.done, 0)])
        == "Agents, 2 waiting for you, 3 working",
      "a lane with nothing in it is not said")
    #expect(
      AccessibilityText.agentsRow([(.waiting, 0), (.working, 0), (.done, 0)])
        == "Agents, nothing running")
  }

  @Test func aWorktreeRowReadsEverythingItsGlyphsMean() {
    var status = WorktreeStatus()
    status.unstaged = 2
    status.changedFiles = 2
    status.ahead = 1
    #expect(
      AccessibilityText.worktree(
        feature, state: .running, status: status, operation: nil, terminalCount: 3,
        isSelected: true)
        == "feat, linked worktree, selected, Working, +0 −0 · 2 modified · ↑1, 3 terminals")
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: WorktreeStatus(), operation: nil, terminalCount: 0,
        isSelected: false) == "feat, linked worktree, Nothing running")
    let failed = WorktreeOperation(.postCreateHook, failure: "npm ERR!")
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: nil, operation: failed, terminalCount: 0, isSelected: false
      )
      .contains("failed: The post-create hook failed"))
  }

  /// The chip is read where it is drawn, on a tab row and a card, and the
  /// chip itself reads the list it hides.
  @Test func aTabRowAndACardSayHowManyWorkersAreOutAndTheChipSaysWhich() {
    let out = [
      Subagent(id: "a", type: "Explore", since: now.addingTimeInterval(-72)),
      Subagent(id: "b", type: nil, since: now.addingTimeInterval(-34)),
    ]
    var withWorkers = card(
      occupant: .agent(id: "claude", name: "Claude Code"), state: .running, secondsAgo: 60)
    withWorkers.subagents = out
    #expect(
      AccessibilityText.card(withWorkers, at: now)
        == "Working, multishell, agents-view, claude — repairReferences, Claude Code, agent, "
        + "2 subagents, for 1m")

    #expect(AccessibilityText.subagents(out) == "2 subagents, Explore, subagent")
    #expect(
      AccessibilityText.pane(
        title: "claude", position: nil, isActive: false, state: .running, subagentCount: 2,
        agent: "Claude Code")
        == "claude, tab, Claude Code, agent, Working, 2 subagents")
    #expect(
      AccessibilityText.pane(
        title: "fix tests", position: (2, 2), isActive: true, state: nil, subagentCount: 0,
        agent: nil)
        == "fix tests, pane 2 of 2, selected",
      "a renamed tab names every pane alike, so the position tells them apart")
  }

  /// The green glyph, in the place it is drawn: after the lock, before the
  /// changes. It is read only where it is drawn, so work that is only in
  /// this worktree silences it here too.
  @Test func aMergedRowSaysSoBetweenItsLockAndItsChanges() {
    var behind = WorktreeStatus()
    behind.behind = 2
    #expect(
      AccessibilityText.worktree(
        feature, state: nil, status: behind, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .merged(.ancestor, into: "origin/main"))
        == "feat, linked worktree, Nothing running, Merged into origin/main, ↓2")

    var dirty = WorktreeStatus()
    dirty.untracked = 1
    dirty.changedFiles = 1
    #expect(
      !AccessibilityText.worktree(
        feature, state: nil, status: dirty, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .merged(.ancestor, into: "origin/main")
      ).contains("Merged"))
    #expect(
      !AccessibilityText.worktree(
        feature, state: nil, status: nil, operation: nil, terminalCount: 0, isSelected: false,
        mergeState: .unmerged
      ).contains("Merged"))
  }

  @Test func aRenamedRowReadsItsNameThenItsBranch() {
    let feature = Worktree(
      path: URL(fileURLWithPath: "/w/feat"), projectID: "/w", head: "abc", branch: "feat")
    #expect(
      AccessibilityText.worktree(
        feature, customName: "Checkout flow", state: nil, status: nil, operation: nil,
        terminalCount: 0, isSelected: false)
        == "Checkout flow, linked worktree, branch feat, Nothing running")
  }

  @Test func theKindNamesBareDetachedMainAndLinked() {
    let main = Worktree(
      path: URL(fileURLWithPath: "/r"), projectID: "/r", head: "abc", branch: "main",
      isPrimary: true)
    let bare = Worktree(
      path: URL(fileURLWithPath: "/r.git"), projectID: "/r.git", head: "", isPrimary: true,
      isBare: true)
    let detached = Worktree(path: URL(fileURLWithPath: "/t/x"), projectID: "/r", head: "1a2e5c9ff")
    #expect(AccessibilityText.kind(of: main) == "Main worktree")
    #expect(AccessibilityText.kind(of: feature) == "Linked worktree")
    #expect(AccessibilityText.kind(of: bare) == "Bare repository")
    #expect(AccessibilityText.kind(of: detached) == "Detached at 1a2e5c9")
  }

  @Test func projectAndTabLabelsSayWhatIsSelectedAndOpen() {
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: false, isMissing: true, state: .attention, worktreeCount: 1)
        == "acme, project, collapsed, 1 worktree, not reachable, Waiting for input")
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: true, isMissing: false, state: nil, worktreeCount: 4)
        == "acme, project, expanded, 4 worktrees")
    #expect(
      AccessibilityText.project(
        name: "acme", isExpanded: true, isMissing: false, state: nil, worktreeCount: 4,
        isFetching: true) == "acme, project, expanded, 4 worktrees, fetching")
    #expect(
      AccessibilityText.tab(title: "zsh", isActive: true, isSplit: true, state: .done, agent: nil)
        == "zsh, tab, selected, split, Done")
    #expect(
      AccessibilityText.tab(
        title: "claude", isActive: false, isSplit: false, state: nil, agent: "Claude Code")
        == "claude, tab, Claude Code, agent",
      "the mark is drawn, so it is said")
    #expect(
      AccessibilityText.tab(
        title: "Claude Code", isActive: false, isSplit: false, state: nil, agent: "Claude Code")
        == "Claude Code, tab",
      "and not twice where the title is already the agent's name")
  }

  /// A worktree with one column has nothing to tell apart, so its strip
  /// says nothing rather than "group 1 of 1" before every tab.
  @Test func aColumnOfTabsNamesItselfOnlyWhereThereAreSeveral() {
    #expect(AccessibilityText.tabGroup(position: 1, of: 1, isFocused: true).isEmpty)
    #expect(
      AccessibilityText.tabGroup(position: 2, of: 3, isFocused: true)
        == "Tab group 2 of 3, focused")
    #expect(AccessibilityText.tabGroup(position: 1, of: 2, isFocused: false) == "Tab group 1 of 2")
  }

  @Test func aDropBandSaysWhichSideTheNewColumnGoes() {
    #expect(AccessibilityText.newTabGroupBand(.before) == "New tab group left")
    #expect(AccessibilityText.newTabGroupBand(.after) == "New tab group right")
  }
}

/// The terminal font picker's rows.
@Suite
struct FontDetectionTests {
  private let fonts = FontDetection(
    monospaced: ["Menlo", "JetBrains Mono"], others: ["Helvetica", "Avenir"])

  @Test func systemFirstThenMonospacedThenADividerThenTheRestSorted() {
    let ids = fonts.options(selected: nil).map(\.id)
    #expect(
      ids == [
        FontDetection.systemID, "JetBrains Mono", "Menlo", FontDetection.dividerID, "Avenir",
        "Helvetica",
      ])
    #expect(fonts.options(selected: nil)[0].label == "System monospace")
  }

  @Test func aStoredFontTheMachineLacksIsListedMarkedRatherThanDropped() {
    let options = fonts.options(selected: "Fira Code")
    let missing = options.first { $0.id == "Fira Code" }
    #expect(missing?.label == "Fira Code (not installed)" && missing?.isInstalled == false)
    #expect(fonts.options(selected: "Menlo").allSatisfy { $0.isInstalled })
    #expect(fonts.options(selected: FontDetection.systemID).allSatisfy { $0.isInstalled })
  }

  @Test func withNoOtherFamiliesThereIsNoDivider() {
    let only = FontDetection(monospaced: ["Menlo"], others: [])
    #expect(!only.options(selected: nil).map(\.id).contains(FontDetection.dividerID))
  }
}

/// The pane's stage titles, and which stages offer its Cancel.
@Suite
struct RemovalStageWordingTests {
  @Test func thePaneNamesTheTrashAndAHookThatDidNotFinish() {
    let removing = WorktreeOperation(.removingWorktree)
    #expect(removing.title == "Moving the worktree to the Trash…")
    #expect(removing.detail.contains("in the Trash"))
    #expect(removing.step.cancelHelp == nil, "git's own stages are left to finish")
    #expect(WorktreeOperation(.postCreateHook).step.cancelHelp?.contains("hook") == true)
    #expect(
      WorktreeOperation(.copyingFiles).step.cancelHelp?.contains("nothing else runs in it") == true,
      "the same Cancel, and what it means where it is not a hook")
    #expect(WorktreeOperation(.linkingFiles).title == "Linking files into the worktree…")
    #expect(
      WorktreeOperation(.linkingFiles, failure: "x").title
        == "Some files were not linked into the worktree")
    #expect(
      WorktreeOperation(.removingWorktree, failure: "x").title
        == "The worktree could not be removed")
    let timedOut = WorktreeOperation(.preDeleteHook, failure: "x", timedOut: true)
    #expect(timedOut.title == "The pre-delete hook did not finish")
    #expect(
      WorktreeOperation(.postCreateHook, failure: "x", timedOut: true).title
        == "The post-create hook did not finish")
  }
}

@Suite
struct StoppedHookPresentationTests {
  @Test func aStoppedOrTimedOutHookIsTitledForWhatEndedIt() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "installing",
      stop: .timedOut(after: .seconds(1)))
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: timedOut))
    #expect(presented.title == "Worktree created, but its hook did not finish")
    #expect(presented.message == "installing\n\nStopped after 1 second, the hook timeout.")

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stop: .stopped)
    let byUser = PresentedError(HookFailure(stage: .preCreate, underlying: stopped))
    #expect(byUser.title == "Worktree not created: its pre-create hook was stopped")
    #expect(byUser.message == "Stopped by you and printed nothing.")
  }

  @Test func theSharedHooksQuestionShowsTheHooksAndNamesTheFile() {
    let pending = PendingSharedHooksTrust(
      projectID: "/r", projectName: "acme", hooks: "post-create:\nnpm ci",
      digest: FileDigest.sha256(of: Data()))
    #expect(pending.title == "Run the hooks in acme's .multishell.json?")
    #expect(pending.message.hasSuffix("post-create:\nnpm ci"))
    #expect(pending.trustLabel == "Run Hooks" && pending.declineLabel == "Ignore Hooks")
  }
}
