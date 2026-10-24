import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// The menus' Auto Rename: a catalogue agent names the row from what its
/// branch changed. The git branch keeps its name; see Docs/design/agents.md.
extension AppModel {
  func isAutoRenaming(_ id: Worktree.ID) -> Bool {
    autoRenames[id] == .running
  }

  /// Why the last Auto Rename left the name as it was, until it is cleared.
  func autoRenameFailure(of id: Worktree.ID) -> String? {
    autoRenames[id]?.failureMessage
  }

  /// The row's warning clicked: the failure has been read, so its banner goes too.
  public func clearAutoRenameFailure(of id: Worktree.ID) {
    guard autoRenameFailure(of: id) != nil else { return }
    autoRenames[id] = nil
    withdrawNotification(about: .worktree(id))
  }

  /// Off while one runs, with no catalogue agent to run or no base to read
  /// against, and where the branch is known to hold nothing of its own.
  public func canAutoRename(_ worktree: Worktree) -> Bool {
    autoRenameStart(for: worktree) != nil
  }

  public func autoRename(_ worktree: Worktree) {
    guard let coordinator, let (base, choice) = autoRenameStart(for: worktree) else { return }
    let id = worktree.id
    let startingName = customName(of: worktree)
    // A new run makes the last one's failure old news.
    if autoRenameFailure(of: id) != nil { withdrawNotification(about: .worktree(id)) }
    autoRenames[id] = .running
    guard let executable = agentDetection.found[choice.agent.id] else {
      let agent = choice.agent.name
      let failure: AutoRenameFailure =
        loginEnvironment == nil ? .stillLooking(agent: agent) : .notInstalled(agent: agent)
      finishAutoRename(
        of: worktree,
        namedAtStart: startingName,
        with: AutoRenameAnswer(branch: worktree.branch, outcome: .failure(failure)),
      )
      return
    }
    let run = AutoRenameRun(
      worktree: worktree,
      base: base,
      choice: choice,
      executable: executable,
      loginVariables: loginEnvironment?.variables ?? [:],
      stopper: oneShotRunner.beginRun(for: id),
    )
    let runner = oneShotRunner.run
    Task { @MainActor [weak self] in
      let answer = await run.answer(using: coordinator.git, runner: runner)
      guard let self, oneShotRunner.endRun(id, stopper: run.stopper), let answer else { return }
      finishAutoRename(of: worktree, namedAtStart: startingName, with: answer)
    }
  }

  /// The base and agent a run would use, read once for the menu and the run;
  /// `nil` where the item is off.
  private func autoRenameStart(for worktree: Worktree) -> (DefaultBranch, AutoRenameChoice)? {
    // A bare repository's empty index reads as the branch deleting every file.
    guard !worktree.isBare, !isAutoRenaming(worktree.id), !isBusy(worktree.id), coordinator != nil,
      let base = defaultBranchScans[worktree.projectID]?.branch,
      let choice = AutoRenameChoice.resolve(
        renameAgentID: workspace.renameAgentID,
        model: workspace.renameModel,
        effort: workspace.renameEffort,
        projectAgentID: effectiveAgentID(for: worktree),
      ),
      !isKnownToHoldNothingToName(worktree, against: base)
    else { return nil }
    return (base, choice)
  }

  /// Nothing staged, and no commit its own: at its base's tip, landed on it,
  /// or the trunk with nothing unpushed. A read not yet made says nothing.
  private func isKnownToHoldNothingToName(
    _ worktree: Worktree,
    against base: DefaultBranch,
  ) -> Bool {
    guard let status = statuses[worktree.id], !status.hasStagedChanges else { return false }
    let tip = scannedBranchTips[worktree.id]
    if tip == base.tip { return true }
    // A verdict counts only for the tip and base it was read at: a read may wait rounds.
    if case .merged(.ancestor, _) = mergeState(of: worktree), tip != nil,
      let basis = mergeVerdictBases[worktree.id], basis.branchTip == tip,
      basis.defaultBranchName == base.shortName
    {
      return true
    }
    guard let branch = worktree.branch else { return worktree.head == base.tip }
    // Behind a remote base after a fetch, which the merge badge leaves unread.
    return branch == base.nameWithoutRemote && status.upstream == base.shortName
      && status.ahead == 0
  }

  /// Drops what no longer stands: a worktree gone, or on a branch neither the
  /// click nor the read saw. A name given meanwhile, or a field open, beats it.
  private func finishAutoRename(
    of started: Worktree,
    namedAtStart startingName: String?,
    with answer: AutoRenameAnswer,
  ) {
    let id = started.id
    guard autoRenames[id] == .running else { return }
    guard let worktree = workspace.worktree(id),
      worktree.branch == answer.branch || worktree.branch == started.branch
    else {
      autoRenames[id] = nil
      return
    }
    switch answer.outcome {
    case .success(let name):
      autoRenames[id] = nil
      guard renamingWorktreeID != id, customName(of: worktree) == startingName else { return }
      renameWorktree(id, to: name)

    case .failure(let failure):
      let message = failure.message
      autoRenames[id] = .failed(message)
      if failure.arrivesLate { notifyAutoRenameFailure(of: worktree, message: message) }
    }
  }

  /// As an agent's failure is: behind the Failed toggle, only off screen, and
  /// a click selects the row.
  private func notifyAutoRenameFailure(of worktree: Worktree, message: String) {
    guard
      NotificationPolicy.shouldNotify(
        .failed,
        preference: workspace.notificationPreference,
        isOnScreen: isWorktreeOnScreen(worktree.id),
      )
    else { return }
    let title = NotificationPolicy.title(
      subject: t("auto-rename.banner-subject"),
      project: workspace.project(worktree.projectID)?.name ?? "",
      worktree: workspace.displayName(of: worktree),
    )
    postNotification(title: title, body: message, about: .worktree(worktree.id))
  }
}
