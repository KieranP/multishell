import MultishellServices

/// What the CI page lists of a run: its workflows, each job's report text and,
/// on the newest run, what Send can carry; see Docs/design/services/send-feedback.md.
public struct CIWorkflowListing: Equatable, Sendable {
  public let workflows: [CIWorkflow]
  /// The newest run's; none for an earlier run, which is history.
  let items: [CIHandoffItem]
  /// The report's text no listed job holds, shown after the workflows.
  public let unplacedExcerpts: [String]
  private let report: CIFailureReport?

  /// What the Latest run's checkbox and the foot cover.
  public var candidates: [HandoffCandidate] { items.map(\.candidate) }

  /// Every job row keeps the trailing slot while any job can be sent.
  public var showsHandoffSlot: Bool { items.contains { $0.position != nil } }

  /// The report's text that names no listed job, where it can be sent.
  public var runOutput: CIHandoffItem? { items.first { $0.position == nil } }

  /// Only the newest run's failures can be sent: earlier runs are history.
  init(run: CIRun, workflows: [CIWorkflow], report: CIFailureReport?, sendsFailures: Bool) {
    let unplaced = report?.unplaced(among: workflows) ?? []
    self.init(
      workflows: workflows,
      report: report,
      items: sendsFailures
        ? CIHandoffItem.items(of: run, workflows: workflows, report: report, unplaced: unplaced)
        : [],
      unplacedExcerpts: unplaced,
    )
  }

  private init(
    workflows: [CIWorkflow],
    report: CIFailureReport?,
    items: [CIHandoffItem],
    unplacedExcerpts: [String],
  ) {
    self.workflows = workflows
    self.report = report
    self.items = items
    self.unplacedExcerpts = unplacedExcerpts
  }

  /// The job at `position` that can be sent, `nil` for one that cannot.
  public func item(at position: CIJobPosition) -> CIHandoffItem? {
    items.first { $0.position == position }
  }

  /// What the report says of the job at `position`.
  public func excerpt(ofJobAt position: CIJobPosition) -> String? {
    if let item = item(at: position) { return item.excerpt }
    let workflow = workflows[position.workflow]
    return report?.excerpt(ofJob: workflow.jobs[position.job].name, inWorkflow: workflow.name)
  }
}
