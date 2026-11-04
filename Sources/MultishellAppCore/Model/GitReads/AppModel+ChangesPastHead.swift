import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Asks git, one at a time, whether each row's tip has a change of its own its
  /// merged head lacks; `asksAgain` re-asks the answered, as remote branches move.
  func readChangesPastHead(ofProject id: Project.ID, asksAgain: Bool = false) async {
    guard let project = workspace.project(id), let git = coordinator?.git else { return }
    let questions = Set(
      workspace.worktrees(of: id).compactMap { remoteState.worktrees[$0.id]?.changesPastMergedHead }
    )
    .filter { question in
      remoteState.changesPastHeadReads[id]?.contains(question) != true
        && (asksAgain
          || (remoteState.changesPastHead[id]?[question] == nil
            && remoteState.unanswerableChangesPastHead[id]?.contains(question) != true))
    }
    guard !questions.isEmpty else { return }
    remoteState.changesPastHeadReads[id, default: []].formUnion(questions)
    var changed = false
    for question in questions {
      let hasChanges = await git.hasChanges(
        on: question.tip,
        pastHead: question.head,
        ownRemoteBranch: question.ownRemoteBranch,
        ownBranch: question.ownBranch,
        in: project,
      )
      // Removed while git ran: `forgetServices` cleared it, so nothing is written.
      guard workspace.project(id) != nil else { return }
      remoteState.changesPastHeadReads[id]?.remove(question)
      // A failed re-ask keeps the answer shown rather than dropping it.
      guard let hasChanges else {
        if remoteState.changesPastHead[id]?[question] == nil {
          remoteState.unanswerableChangesPastHead[id, default: []].insert(question)
        }
        continue
      }
      remoteState.unanswerableChangesPastHead[id]?.remove(question)
      if remoteState.changesPastHead[id]?[question] != hasChanges {
        remoteState.changesPastHead[id, default: [:]][question] = hasChanges
        changed = true
      }
    }
    if changed { recomputeWorktreeServices(ofProject: id) }
  }
}
