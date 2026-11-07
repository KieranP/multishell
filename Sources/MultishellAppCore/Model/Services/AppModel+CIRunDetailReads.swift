import Foundation
import MultishellCore
import MultishellServices

extension AppModel {
  public func ciWorkflows(ofRun run: CIRun) -> [CIWorkflow]? {
    remoteState.ciWorkflows[run.id]?.value
  }

  /// Why the run's workflows or report could not be read, `nil` once a read answers.
  public func ciRunDetailProblem(ofRun run: CIRun, for worktree: Worktree) -> String? {
    let failure =
      remoteState.workflowReadFailures[run.id]
      ?? (run.status == .failed ? remoteState.reportReadFailures[run.id] : nil)
    guard let failure, let project = workspace.project(worktree.projectID),
      let (integration, _) = ciProvider(for: project)
    else { return nil }
    return failure.reason(integration: integration)
  }

  /// A run of the panel's history, read as its row opens.
  public func readCIRunDetails(of run: CIRun, for worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID) else { return }
    await readCIRunDetails(of: run, in: project)
  }

  /// A run's workflows and, where it failed, its report, read together.
  func readCIRunDetails(of run: CIRun, in project: Project) async {
    async let workflows: Void = readCIWorkflows(of: run, in: project)
    async let report: Void = readFailureReport(of: run, in: project)
    _ = await (workflows, report)
  }

  /// A run listed as going whose details were read after it ended was rerun,
  /// so they describe the attempt before; unlisted then, it would keep them.
  func forgetDetailsOfRerunRuns(_ listed: [CIRun]) {
    for run in listed where !run.isFinished {
      if remoteState.ciWorkflows[run.id]?.runWasFinished == true {
        setIfChanged(\.remoteState.ciWorkflows[run.id], nil)
        remoteState.workflowsReadAt[run.id] = nil
      }
      if remoteState.failureReports[run.id]?.runWasFinished == true {
        setIfChanged(\.remoteState.failureReports[run.id], nil)
        remoteState.reportsReadAt[run.id] = nil
      }
    }
  }

  /// A run still going can fail another job, so its report is read again,
  /// and once more as it ends; one read at a time per run.
  private func readFailureReport(of run: CIRun, in project: Project) async {
    guard run.status == .failed,
      remoteState.failureReports[run.id]?.stillDescribe(
        run,
        readAt: remoteState.reportsReadAt[run.id],
      )
        != true,
      let (integration, provider) = ciProvider(for: project),
      remoteState.reportReads.insert(run.id).inserted
    else { return }
    defer { remoteState.reportReads.remove(run.id) }
    let changesBefore = remoteState.integrationChanges[project.id]
    let report: CIFailureReport?
    var failure: ServiceReadFailure?
    do {
      report = try await provider.failureReport(of: run, in: project.path)
    } catch {
      report = nil
      failure = ServiceReadFailure(error)
    }
    guard stillReads(integration, for: project, changedSince: changesBefore) else { return }
    setIfChanged(\.remoteState.reportReadFailures[run.id], failure)
    guard let report else { return }
    remoteState.reportsReadAt[run.id] = .now
    setIfChanged(
      \.remoteState.failureReports[run.id],
      CIRunDetail(value: report, runStatus: run.status, runWasFinished: run.isFinished),
    )
  }

  /// A settled run's workflows do not change, so they are read once; one read
  /// at a time per run.
  private func readCIWorkflows(of run: CIRun, in project: Project) async {
    let readAt = remoteState.workflowsReadAt[run.id]
    if remoteState.ciWorkflows[run.id]?.stillDescribe(run, readAt: readAt) == true { return }
    guard let (integration, provider) = ciProvider(for: project),
      remoteState.workflowReads.insert(run.id).inserted
    else { return }
    defer { remoteState.workflowReads.remove(run.id) }
    let changesBefore = remoteState.integrationChanges[project.id]
    let workflows: [CIWorkflow]?
    var failure: ServiceReadFailure?
    do {
      workflows = try await provider.workflows(of: run, in: project.path)
    } catch {
      workflows = nil
      failure = ServiceReadFailure(error)
    }
    guard stillReads(integration, for: project, changedSince: changesBefore) else { return }
    setIfChanged(\.remoteState.workflowReadFailures[run.id], failure)
    guard let workflows else { return }
    remoteState.workflowsReadAt[run.id] = .now
    setIfChanged(
      \.remoteState.ciWorkflows[run.id],
      CIRunDetail(value: workflows, runStatus: run.status, runWasFinished: run.isFinished),
    )
  }

  /// Gone, or its provider turned off, gone or replaced, while `circleci` ran:
  /// what it read is kept by nothing that asks.
  private func stillReads(
    _ integration: ServiceIntegration,
    for project: Project,
    changedSince changesBefore: Int?,
  ) -> Bool {
    workspace.project(project.id) != nil && ciProvider(for: project)?.0 == integration
      && remoteState.integrationChanges[project.id] == changesBefore
  }
}
