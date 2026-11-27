import MultishellCore
import MultishellGitKit

/// Merge from Base and Rebase onto Base; see Docs/design/worktrees/updating-from-base.md.
extension AppModel {
  /// The base the menu names, `nil` where it offers neither item: detached, bare,
  /// on the base itself, or in a project with none resolved.
  func updatableBase(of worktree: Worktree) -> DefaultBranch? {
    guard !worktree.isBare, let branch = worktree.branch,
      let base = defaultBranch(ofWorktree: worktree.id), !base.isSameBranch(as: branch)
    else { return nil }
    return base
  }

  /// The menu's click: refused over a stop or uncommitted changes, asked first where
  /// an agent works there or a rebase rewrites pushed commits, else run.
  public func requestBaseUpdate(of worktree: Worktree, by method: UpdateMethod) async {
    guard let git = coordinator?.git, mayStartBaseUpdate(worktree),
      let base = updatableBase(of: worktree)
    else { return }
    let question: PendingBaseUpdate
    switch await checkBaseUpdate(worktree, by: method, onto: base, using: git) {
    case .failure(let refusal):
      await present(refusal, of: worktree, by: method, onto: base)
      return

    case .success(let asked): question = asked
    }
    guard !question.exceeds(BaseUpdateConsent()) else {
      ask(question)
      return
    }
    let attempt = await runBaseUpdate(worktree, by: method, onto: base, consenting: .init())
    await present(attempt, of: worktree, by: method, onto: base)
  }

  /// The dialog's answer. The run reads everything again after its fetch: the agent
  /// went on while the question stood.
  @discardableResult
  public func answerBaseUpdate(_ pending: PendingBaseUpdate, confirmed: Bool) -> Task<Void, Never>?
  {
    // SwiftUI may clear the dialog's binding, answering No, before running the
    // confirm; it still stands then, but never over another question.
    let answersThisQuestion =
      pendingBaseUpdate == pending || (confirmed && pendingBaseUpdate == nil)
    guard answersThisQuestion else { return nil }
    pendingBaseUpdate = nil
    guard confirmed else { return nil }
    return Task {
      let attempt = await runBaseUpdate(
        pending.worktree,
        by: pending.method,
        onto: pending.base,
        consenting: pending.consent,
      )
      await present(attempt, of: pending.worktree, by: pending.method, onto: pending.base)
    }
  }

  /// The fetch, then everything read again, as a fetch can take minutes while an agent
  /// edits or switches branch, then the merge or rebase. Conflicts go where the project says.
  func runBaseUpdate(
    _ worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
    consenting consent: BaseUpdateConsent,
  ) async -> BaseUpdateAttempt {
    guard let git = coordinator?.git, mayStartBaseUpdate(worktree) else { return .notStarted }
    setIfChanged(\.baseUpdateSteps[worktree.id], .fetching)
    defer { setIfChanged(\.baseUpdateSteps[worktree.id], nil) }
    do {
      try await git.fetch(base, in: worktree)
    } catch {
      if workspace.worktree(worktree.id) != nil { present(error) }
      return .failed
    }
    guard !Task.isCancelled else { return .cancelled }
    setIfChanged(\.baseUpdateSteps[worktree.id], .checking)
    if let refusal = await baseUpdateRefusal(worktree, onto: base, using: git) {
      return .refused(refusal)
    }
    let question = await baseUpdateQuestion(worktree, by: method, onto: base, using: git)
    guard !question.exceeds(consent) else { return .asks(question) }
    guard !Task.isCancelled else { return .cancelled }
    setIfChanged(\.baseUpdateSteps[worktree.id], .updating(method))
    let outcome: BaseUpdateOutcome
    do {
      outcome = try await git.update(worktree, from: base, by: method)
    } catch {
      // A worktree removed while git ran is no one's to alert about.
      if workspace.worktree(worktree.id) != nil { present(error) }
      await refreshAfterBaseUpdate(of: worktree)
      return .failed
    }
    await refreshAfterBaseUpdate(of: worktree)
    // Past here git has written: a hang-up still leaves the stop where the setting sends it.
    guard case .unfinished(let paths) = outcome,
      workspace.worktree(worktree.id) != nil, let project = effectiveProject(of: worktree),
      workspace.sendsConflictsToPreferredAgent(for: project)
    else { return .ran(BaseUpdateRun(outcome: outcome, conflictPane: nil)) }
    let pane = openConflictTab(
      in: worktree,
      named: workspace.displayName(of: worktree),
      method: method,
      paths: paths,
      selecting: false,
    )
    return .ran(BaseUpdateRun(outcome: outcome, conflictPane: pane))
  }

  /// What the click says of a run: a refusal's alert, or the question a new reason asks.
  private func present(
    _ attempt: BaseUpdateAttempt,
    of worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
  ) async {
    switch attempt {
    case .asks(let question): ask(question)
    case .refused(let refusal): await present(refusal, of: worktree, by: method, onto: base)
    case .cancelled, .failed, .notStarted, .ran: break
    }
  }

  private func ask(_ question: PendingBaseUpdate) {
    guard !beepIfAQuestionWaits() else { return }
    pendingBaseUpdate = question
  }

  /// A rebase leaves the branch detached while it stops, which only the list
  /// says, and the row's status reads the stop.
  func refreshAfterBaseUpdate(of worktree: Worktree) async {
    if let project = workspace.project(worktree.projectID) { await refreshWorktrees(of: project) }
    await refreshStatus(of: worktree.id, forced: true)
  }

  /// What the worktree is called while a rebase stops there: its user's name, else
  /// the branch git lists it without until the rebase ends, not the short commit.
  func displayNameWhileUnfinished(of worktree: Worktree, using git: WorktreeGit) async -> String {
    if let custom = workspace.customName(of: worktree.id) { return custom }
    return await git.branchBeingRebased(in: worktree.path) ?? worktree.name
  }
}
