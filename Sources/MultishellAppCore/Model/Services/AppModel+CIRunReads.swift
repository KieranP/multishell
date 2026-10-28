import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  private static var concurrentBranchRunLookups: Int { 4 }

  /// The project's recent runs in one call, and alone each shown pushed branch
  /// they left out. A failure keeps the runs before it.
  func readCIRuns(
    of project: Project,
    remotes: [GitRemote]?,
    after previous: ProjectCIRuns?,
  ) async -> ProjectCIRuns? {
    guard let (integration, provider) = ciProvider(for: project) else { return nil }
    guard await runsOn(provider, project: project) else {
      return ProjectCIRuns(integration: integration, isConfigured: false, runsByBranch: [:])
    }
    let changesBefore = remoteState.integrationChanges[project.id]
    var reading =
      previous.flatMap { $0.integration == integration ? $0 : nil }
      ?? ProjectCIRuns(integration: integration, runsByBranch: [:])
    reading.isConfigured = true
    // As the host's: the same remotes get the same answer until a login.
    if reading.failure == .notHosted, remotes == nil || remotes == reading.remotes,
      ServiceReadInterval.notHostedStands(since: reading.notHostedSince)
    {
      return reading
    }
    // A failed git read keeps the remotes before it.
    if let remotes { reading.remotes = remotes }
    do {
      let recent = try await provider.recentRuns(in: project.path)
      forgetDetailsOfRerunRuns(recent)
      // Newest first, so the first of each branch is its latest.
      var runsByBranch = Dictionary(keepingFirst: recent.map { ($0.branch, $0) })
      let listed = Set(runsByBranch.keys)
      let leftOut = shownUpstreamBranches(ofProject: project.id).filter { branch, _ in
        runsByBranch[branch] == nil
      }
      let (lookups, lookupFailures, askedAndAnswered) = await lookUpBranches(
        leftOut,
        with: provider,
        in: project,
        reusing: reading.lookups,
      )
      // A branch missing from the lookups failed to answer, so keeps its last run.
      for branch in leftOut.keys {
        runsByBranch[branch] = lookups[branch].map(\.run) ?? reading.runsByBranch[branch]
      }
      // A branch hidden this round keeps its answer, or its return would ask
      // again; one the recent runs list has a newer answer than any lookup.
      let followed = Set(
        workspace.worktrees(of: project.id).compactMap { remoteState.upstreams[$0.id]?.branch }
      )
      reading.lookups = reading.lookups
        .filter { followed.contains($0.key) && !listed.contains($0.key) }
        .merging(lookups) { _, fresh in fresh }
      // A hidden branch's kept answer stands for it too, or its return would
      // show no run until the next read.
      for (branch, lookup) in reading.lookups where runsByBranch[branch] == nil {
        runsByBranch[branch] = lookup.run
      }
      reading.runsByBranch = runsByBranch
      reading.hasAnswered = true
      reading.failure = nil
      reading.branchFailures = lookupFailures
      reading.notHostedSince = nil
      recordCIAnswerTimes(
        of: project,
        unless: remoteState.integrationChanges[project.id] != changesBefore,
        answered: listed.union(askedAndAnswered),
        followed: followed,
      )
    } catch {
      reading.recordFailure(ServiceReadFailure(error))
    }
    return reading
  }

  /// Only a followed branch's row ever reads its time; the recent runs name
  /// hundreds of others a day. Gone, or its integrations changed, while it ran: none.
  private func recordCIAnswerTimes(
    of project: Project,
    unless integrationsChanged: Bool,
    answered: Set<String>,
    followed: Set<String>,
  ) {
    let id = project.id
    guard workspace.project(id) != nil, !integrationsChanged else { return }
    let now = Date.now
    remoteState.ciRunsAnsweredAt[id] = now
    let kept = (remoteState.ciBranchesAnsweredAt[id] ?? [:]).filter { followed.contains($0.key) }
    remoteState.ciBranchesAnsweredAt[id] =
      kept.merging(answered.intersection(followed).map { ($0, now) }) { _, fresh in fresh }
  }

  /// The provider's file in the project's own checkout or any worktree's,
  /// a bare repository having no checkout of its own.
  func runsOn(_ provider: any CIProvider, project: Project) async -> Bool {
    let directories = [project.path] + workspace.worktrees(of: project.id).map(\.path)
    let path = provider.configurationPath
    return await runOnDispatch {
      directories.contains { directory in
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(path).path)
      }
    }
  }

  /// Each shown worktree's branch on the remote and where it points there. A
  /// branch nobody pushed, or the remote has since deleted, has no run to find.
  private func shownUpstreamBranches(ofProject id: Project.ID) -> [String: String?] {
    let shown = sidebarRowIDs()
    var branches: [String: String?] = [:]
    for worktree in workspace.worktrees(of: id)
    where shown.contains(worktree.id) || worktree.id == workspace.selectedWorktreeID {
      if let upstream = remoteState.upstreams[worktree.id], upstream.tip != nil {
        branches[upstream.branch] = upstream.tip
      }
    }
    return branches
  }

  /// A branch that fails to answer is left out, keeping the run it showed and
  /// asked again next round; its failure is said on its own row.
  private func lookUpBranches(
    _ branches: [String: String?],
    with provider: any CIProvider,
    in project: Project,
    reusing previous: [String: BranchRunLookup],
  ) async -> (
    lookups: [String: BranchRunLookup],
    failures: [String: ServiceReadFailure],
    askedAndAnswered: Set<String>
  ) {
    var lookups: [String: BranchRunLookup] = [:]
    var asking: [(branch: String, tip: String?)] = []
    for (branch, tip) in branches {
      if let kept = previous[branch], kept.stillAnswers(upstreamTip: tip) {
        lookups[branch] = kept
      } else {
        asking.append((branch, tip))
      }
    }
    let directory = project.path
    let answers = await asking.mapConcurrentlyUnordered(width: Self.concurrentBranchRunLookups) {
      asked -> (String, String?, Result<CIRun?, any Error>) in
      do {
        let run = try await provider.runs(onBranch: asked.branch, limit: 1, in: directory).first
        return (asked.branch, asked.tip, .success(run))
      } catch {
        return (asked.branch, asked.tip, .failure(error))
      }
    }
    var failures: [String: ServiceReadFailure] = [:]
    var askedAndAnswered: Set<String> = []
    for (branch, tip, result) in answers {
      switch result {
      case .success(let run):
        lookups[branch] = BranchRunLookup(upstreamTip: tip, run: run)
        askedAndAnswered.insert(branch)

      case .failure(let error):
        failures[branch] = ServiceReadFailure(error)
      }
    }
    return (lookups, failures, askedAndAnswered)
  }
}
