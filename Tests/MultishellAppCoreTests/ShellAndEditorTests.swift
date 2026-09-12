import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct ShellDetectionTests {
  @Test func shellsComeFromTheSystemListAndThePathWithoutDuplicates() throws {
    // Only `/bin/sh` is assumed to exist: the Linux CI image has no zsh.
    let bin = try fakeBin(["fish", "zsh", "nu", "bash"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let list = bin.appendingPathComponent("shells")
    try """
    # List of acceptable shells for chpass(1).

    /bin/sh
    \(bin.appendingPathComponent("bash").path)
    \(bin.appendingPathComponent("zsh").path)
    /no/such/shell
    """.write(to: list, atomically: true, encoding: .utf8)

    let detection = ShellDetection(path: bin.path, systemList: list, loginShell: "/bin/sh")

    #expect(
      detection.installed == [
        bin.appendingPathComponent("bash").path, bin.appendingPathComponent("fish").path,
        bin.appendingPathComponent("nu").path, "/bin/sh", bin.appendingPathComponent("zsh").path,
      ], "sorted by name then path, listed once, the missing one dropped")
    #expect(detection.isInstalled("/bin/sh"))
    #expect(detection.isInstalled(ShellCatalogue.loginShellID))
    #expect(!detection.isInstalled("/opt/gone/fish"))
  }

  @Test func theDropdownLeadsWithTheLoginShellAndKeepsAStaleChoice() {
    let detection = ShellDetection(installed: ["/bin/bash", "/bin/zsh"], loginShell: "/bin/zsh")

    let plain = detection.options(selected: nil)
    #expect(plain.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "custom"])
    #expect(plain[0].label == "Login shell (/bin/zsh)")
    #expect(plain[1].label == "bash  /bin/bash")
    #expect(plain.last?.label == "Custom path…")

    let stale = detection.options(selected: "/opt/homebrew/bin/fish")
    #expect(
      stale.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "/opt/homebrew/bin/fish", "custom"])
    #expect(stale[3].label == "fish  /opt/homebrew/bin/fish (not installed)")
    #expect(stale[3].isInstalled == false)
    #expect(detection.options(selected: "/bin/bash").count == 4, "an installed choice adds nothing")
    #expect(detection.options(selected: "custom").count == 4, "and neither does the custom path")
    #expect(detection.isInstalled(ShellCatalogue.customID))
  }

  /// Every other row is checked against the disk. `$SHELL` pointing at an
  /// uninstalled fish showed an unmarked row, and each new tab died silently.
  @Test func aLoginShellThatIsNotThereIsMarkedLikeAnyOtherMissingOne() {
    let gone = ShellDetection(installed: ["/bin/zsh"], loginShell: "/opt/gone/fish")
    #expect(!gone.isInstalled(ShellCatalogue.loginShellID))
    #expect(gone.options(selected: nil)[0].isInstalled == false)

    let there = ShellDetection(installed: ["/bin/zsh"], loginShell: "/bin/sh")
    #expect(there.isInstalled(ShellCatalogue.loginShellID))
    #expect(there.options(selected: nil)[0].isInstalled)
  }

  @Test func aMissingSystemListIsNotAnError() {
    let detection = ShellDetection(
      path: "/nowhere", systemList: URL(fileURLWithPath: "/no/such/shells"), loginShell: "/bin/sh")
    #expect(detection.installed.isEmpty)
    #expect(detection.options(selected: nil).map(\.id) == ["login", "custom"])
  }
}

@Suite
struct EditorDetectionTests {
  @Test func editorsAreFoundByBundleIdOrByShimAndTerminalOnesByShimOnly() throws {
    let bin = try fakeBin(["code", "nvim"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let apps = ["dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app")]

    let detection = EditorDetection(path: bin.path) { apps[$0] }

    #expect(Set(detection.found.keys) == ["vscode", "zed", "nvim"])
    #expect(detection.found["zed"]?.application?.path == "/Applications/Zed.app")
    #expect(detection.found["zed"]?.command == nil)
    #expect(detection.found["vscode"]?.application == nil, "found through its shim only")
    #expect(detection.found["vscode"]?.command?.path == bin.appendingPathComponent("code").path)
    #expect(detection.found["nvim"]?.command?.path == bin.appendingPathComponent("nvim").path)
    #expect(detection.isInstalled("custom") && !detection.isInstalled("cursor"))
  }

  @Test func theDropdownListsInstalledEditorsTheStaleChoiceAndCustom() {
    let detection = EditorDetection(found: [
      "zed": .init(application: URL(fileURLWithPath: "/Applications/Zed.app"), command: nil)
    ])
    #expect(detection.options(selected: nil).map(\.id) == ["none", "zed", "custom"])

    let stale = detection.options(selected: "vscode")
    #expect(stale.map(\.id) == ["none", "vscode", "zed", "custom"], "catalogue order")
    #expect(stale[1].label == "Visual Studio Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-editor")
    #expect(unknown.map(\.id).contains("future-editor"), "a newer build's id still shows")
  }

  @Test func theAgentAndEditorDropdownsShareOneShape() {
    let agents = AgentDetection(found: [:]).options(selected: "custom")
    let editors = EditorDetection(found: [:]).options(selected: "custom")
    #expect(agents == editors, "nothing installed and Custom chosen: identical rows")
    #expect(agents.map(\.id) == ["none", "custom"], "a chosen Custom adds no stale row")
    #expect(agents.last?.label == "Custom command…")
    #expect(
      AgentDetection(found: [:]).options(selected: "none").map(\.id) == ["none", "custom"],
      "and neither does a chosen None")
  }
}

@Suite
struct EditorLaunchTests {
  private let zsh = (executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-l", "-i", "-c"])
  private let directory = URL(fileURLWithPath: "/Users/me/Work/repo trees/feat")

  private func action(
    _ id: String, found: EditorDetection.Found? = nil, custom: String = ""
  ) -> EditorLaunch.Action? {
    EditorLaunch.action(
      editorID: id, found: found, customTemplate: custom, directory: directory, shell: zsh,
      exec: "exec /bin/zsh -l")
  }

  @Test func anApplicationIsPreferredOverItsShimAndTheShimRunsInTheBackground() {
    let app = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
    let shim = URL(fileURLWithPath: "/opt/homebrew/bin/code")
    #expect(
      action("vscode", found: .init(application: app, command: shim)) == .openApplication(app))
    #expect(
      action("vscode", found: .init(application: nil, command: shim))
        == .runInBackground("/opt/homebrew/bin/code '/Users/me/Work/repo trees/feat'"))
    #expect(action("vscode", found: nil) == nil, "in the catalogue, not installed")
    #expect(action("no-such-editor") == nil)
  }

  @Test func aTerminalEditorIsATabRunningItInTheWorktreeWithAShellAfter() {
    let nvim = URL(fileURLWithPath: "/opt/homebrew/bin/nvim")
    #expect(
      action("nvim", found: .init(application: nil, command: nvim))
        == .openTab(
          title: "Neovim",
          command: ["/bin/zsh", "-l", "-i", "-c", "/opt/homebrew/bin/nvim .; exec /bin/zsh -l"]))
    #expect(action("nvim", found: .init(application: nil, command: nil)) == nil)
  }

  @Test func theCustomTemplateBecomesATabNamedForItsCommand() {
    #expect(
      action("custom", custom: "code-insiders {path}")
        == .openTab(
          title: "code-insiders",
          command: [
            "/bin/zsh", "-l", "-i", "-c",
            "code-insiders '/Users/me/Work/repo trees/feat'; exec /bin/zsh -l",
          ]))
    #expect(action("custom", custom: "/usr/local/bin/micro")?.self.title == "micro")
    #expect(action("custom", custom: "   ") == nil, "nothing typed")
  }
}

extension EditorLaunch.Action {
  fileprivate var title: String? {
    if case .openTab(let title, _) = self { return title }
    return nil
  }
}

@Suite
struct PendingWorktreeRemovalTests {
  private let branched = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"), projectID: "/repo", head: "abc", branch: "feat")
  private let detached = Worktree(
    path: URL(fileURLWithPath: "/trees/pinned"), projectID: "/repo", head: "abc1234")

  /// The dialog the decision asks for, or a failed requirement.
  private func asked(
    _ worktree: Worktree, confirms: Bool, alwaysDeletesBranch: Bool,
    mergeState: WorktreeMergeState = .unknown
  ) throws -> PendingWorktreeRemoval {
    let decision = PendingWorktreeRemoval.decide(
      worktree, confirms: confirms, alwaysDeletesBranch: alwaysDeletesBranch,
      mergeState: mergeState)
    guard case .ask(let pending) = decision else {
      throw RemovalTestFailure(decision: decision)
    }
    return pending
  }

  private struct RemovalTestFailure: Error {
    let decision: PendingWorktreeRemoval.Decision
  }

  @Test func withConfirmationOnTheDialogAsksAboutTheBranchUnlessASettingSettlesIt() throws {
    let pending = try asked(branched, confirms: true, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "one button for the branch, one without it")
    #expect(!pending.deletesBranch)
    #expect(pending.removeLabel == "Remove Worktree")
    #expect(pending.removeWithBranchLabel == "Remove Worktree and Branch")
    #expect(pending.title == "Remove worktree feat?")

    let settled = try asked(branched, confirms: true, alwaysDeletesBranch: true)
    #expect(settled.choices.count == 1)
    #expect(settled.deletesBranch)
    #expect(settled.removeLabel == "Remove Worktree and Branch", "one button, saying what it does")
  }

  /// The dialog names the row the user right-clicked. The branch is still
  /// in the body: that is the part that cannot be undone.
  @Test func aRenamedWorktreeIsAskedAboutByItsName() throws {
    let decision = PendingWorktreeRemoval.decide(
      branched, customName: "Checkout flow", confirms: true, alwaysDeletesBranch: false)
    guard case .ask(let pending) = decision else { throw RemovalTestFailure(decision: decision) }
    #expect(pending.title == "Remove worktree Checkout flow?")
    #expect(pending.message(warning: nil).contains("The branch feat is kept unless"))
  }

  @Test func withConfirmationOffOnlyAnOpenBranchQuestionStillAsks() throws {
    #expect(
      PendingWorktreeRemoval.decide(branched, confirms: false, alwaysDeletesBranch: true)
        == .remove(deletingBranch: true))
    #expect(
      PendingWorktreeRemoval.decide(detached, confirms: false, alwaysDeletesBranch: false)
        == .remove(deletingBranch: false), "nothing to ask about a detached worktree")
    let pending = try asked(branched, confirms: false, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "deleting a branch is not undone from the sidebar")
  }

  @Test func aDetachedWorktreeNeverHasItsBranchDeleted() throws {
    let pending = try asked(detached, confirms: true, alwaysDeletesBranch: true)
    #expect(!pending.deletesBranch && pending.choices.count == 1)
    #expect(pending.removeLabel == "Remove Worktree")
    #expect(!pending.message(warning: nil).contains("branch"))
  }

  @Test func theWarningCountsChangedFilesAndOpenTerminalsOrSaysNothing() {
    #expect(PendingWorktreeRemoval.warning(changedFiles: 0, liveTerminals: 0) == nil)
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 1, liveTerminals: 0)
        == "It has 1 changed file, kept in the Trash with the directory.")
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 0, liveTerminals: 2)
        == "2 open terminals will be closed.")
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 3, liveTerminals: 1)
        == "It has 3 changed files, kept in the Trash with the directory. 1 open terminal will be closed."
    )
  }

  @Test func theMessageNamesThePathTheBranchsFateAndTheWarning() {
    let asks = PendingWorktreeRemoval(worktree: branched, branch: .asks)
    #expect(
      asks.message(warning: "2 open terminals will be closed.")
        == "Moves /trees/feat to the Trash and prunes it from git.\n\nThe branch feat is kept unless you remove it too.\n\n2 open terminals will be closed."
    )
    let deletes = PendingWorktreeRemoval(worktree: branched, branch: .decided(deletes: true))
    #expect(deletes.message(warning: nil).hasSuffix("The branch feat is deleted with it."))
    let keeps = PendingWorktreeRemoval(worktree: branched, branch: .decided(deletes: false))
    #expect(keeps.message(warning: nil).hasSuffix("The branch feat is kept."))
  }

  @Test func aMergedBranchLeadsWithTheButtonThatDeletesItAndSaysWhy() throws {
    let decision = PendingWorktreeRemoval.decide(
      branched, confirms: true, alwaysDeletesBranch: false,
      mergeState: .merged(.ancestor, into: "origin/main"))
    guard case .ask(let pending) = decision else { throw RemovalTestFailure(decision: decision) }
    #expect(pending.choices.map(\.deletesBranch) == [true, false])
    #expect(pending.choices.first?.label == "Remove Worktree and Branch")
    #expect(pending.message(warning: nil).contains("feat is merged into origin/main."))
  }

  @Test func anUpstreamThatHasGoneIsNotEnoughToLeadWithDeletingTheBranch() throws {
    let pending = try asked(
      branched, confirms: true, alwaysDeletesBranch: false,
      mergeState: .merged(.upstreamGone, into: "origin/main"))
    #expect(pending.choices.map(\.deletesBranch) == [false, true], "keeping it stays the default")
    #expect(pending.message(warning: nil).contains("likely squash-merged"))
  }

  @Test func aSettledBranchQuestionStillOffersOneButtonWhateverTheMergeState() throws {
    let pending = try asked(
      branched, confirms: true, alwaysDeletesBranch: true,
      mergeState: .merged(.ancestor, into: "origin/main"))
    #expect(
      pending.choices == [
        PendingWorktreeRemoval.Choice(label: "Remove Worktree and Branch", deletesBranch: true)
      ])
  }
}

@Suite
struct WorktreeOperationTests {
  @Test func eachStepHasATitleAndSaysWhatHappensWhenItEnds() {
    let create = WorktreeOperation(.postCreateHook)
    #expect(create.step == .postCreateHook)
    #expect(create.title == "Running the post-create hook…")
    #expect(create.detail.contains("first terminal opens"))

    let removal = WorktreeOperation(WorktreeRemovalStep.preDeleteHook)
    #expect(removal.step == .preDeleteHook)
    #expect(removal.detail.contains("stays if the hook refuses"))
    #expect(WorktreeOperation(WorktreeRemovalStep.deletingBranch).title == "Deleting the branch…")
    #expect(
      WorktreeOperation(WorktreeRemovalStep.removingWorktree).detail
        == WorktreeOperation(WorktreeRemovalStep.postDeleteHook).detail)
  }

  @Test func aFailureChangesTheTitleAndTheDetailAndEndsTheRun() {
    var hook = WorktreeOperation(.postCreateHook)
    #expect(hook.isRunning)
    hook.failure = "npm ERR! nope"
    #expect(!hook.isRunning)
    #expect(hook.title == "The post-create hook failed")
    #expect(hook.detail.contains("Dismiss to open its first terminal"))

    let veto = WorktreeOperation(.preDeleteHook, failure: "")
    #expect(veto.title == "The pre-delete hook refused the removal")
    #expect(veto.detail.contains("terminals stay"))
  }
}

@Suite
struct PendingProjectRemovalTests {
  @Test func theMessageCountsLiveTerminalsAndSaysTheDiskIsUntouched() {
    let none = PendingProjectRemoval.message(liveTerminals: 0)
    #expect(none.hasPrefix("Takes the project and its worktrees out of the sidebar."))
    #expect(!none.contains("terminal"))
    #expect(none.contains("Nothing on disk is touched"))
    #expect(PendingProjectRemoval.message(liveTerminals: 1).contains("1 open terminal will"))
    #expect(PendingProjectRemoval.message(liveTerminals: 3).contains("3 open terminals will"))
  }

  @Test func eachWindowPresentsOnlyItsOwnRequest() {
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let pending = PendingProjectRemoval(project: project, source: .settings)
    #expect(pending.id == project.id)
    #expect(pending.title == "Remove project demo?")
    #expect(pending.source == .settings && pending.source != .workspace)
  }
}
