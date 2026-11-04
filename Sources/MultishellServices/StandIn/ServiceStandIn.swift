import Foundation

/// Pull requests and CI runs `multishell debug services stand-in` hands the app,
/// answered in place of `gh` and `circleci`; see Docs/design/services.md.
public struct ServiceStandIn: Sendable {
  /// What the Integrations page names as either tool's version.
  static let toolVersion = "stand-in"

  /// Newest first, as `gh` lists them, undated ones last, ties in the order given.
  let pullRequests: [PullRequest]
  /// By `key(of:)`: two repositories' may share a number.
  let checks: [String: [PullRequestCheck]]
  /// Newest first, undated ones last, ties in the order given.
  let runs: [CIRun]
  let workflows: [CIRun.ID: [CIWorkflow]]
  let failureReports: [CIRun.ID: CIFailureReport]

  public var pullRequestHost: any PullRequestHost { StandInPullRequestHost(standIn: self) }
  public var ciProvider: any CIProvider { StandInCIProvider(standIn: self) }

  /// Throws `ServiceStandInUnreadable`, naming the key it stopped at.
  public init(json: String) throws(ServiceStandInUnreadable) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = Data(json.utf8)
    try ServiceStandInFields.check(data)
    let record: ServiceStandInRecord
    do {
      record = try decoder.decode(ServiceStandInRecord.self, from: data)
    } catch {
      throw ServiceStandInUnreadable(error)
    }
    let pullRequests = record.pullRequests ?? []
    let runs = record.ciRuns ?? []
    var seenRunIDs: Set<CIRun.ID> = []
    if let repeated = runs.indices.first(where: { !seenRunIDs.insert(runs[$0].id).inserted }) {
      throw ServiceStandInUnreadable(
        at: "ciRuns.\(repeated).id",
        "run \(runs[repeated].id) is given twice",
      )
    }
    let built = pullRequests.map { record in
      (record.pullRequest, (record.checks ?? []).map(\.check))
    }
    var seenKeys: Set<String> = []
    if let repeated = built.indices.first(where: { index in
      !seenKeys.insert(Self.key(of: built[index].0)).inserted
    }) {
      throw ServiceStandInUnreadable(
        at: "pullRequests.\(repeated).number",
        "#\(built[repeated].0.number) into \(built[repeated].0.baseBranch) is given twice",
      )
    }
    self.pullRequests = built.map(\.0).newestFirst(by: \.updatedAt)
    checks = Dictionary(uniqueKeysWithValues: built.map { (Self.key(of: $0.0), $0.1) })
    self.runs = runs.map(\.run).newestFirst { $0.createdAt ?? .distantPast }
    workflows = Dictionary(
      uniqueKeysWithValues: runs.map { ($0.id, ($0.workflows ?? []).map(\.workflow)) }
    )
    failureReports = Dictionary(
      uniqueKeysWithValues: runs.map { run in
        (run.id, CIFailureReport(excerpts: (run.failures ?? []).map(\.excerpt)))
      }
    )
  }

  /// What tells one pull request from another: its head repository, number and
  /// base, numbers being a base repository's, which a stand-in does not name.
  static func key(of pullRequest: PullRequest) -> String {
    // Hosts compare owner and name without case, and branch names with it.
    "\(pullRequest.headRepository.identity)#\(pullRequest.number)>\(pullRequest.baseBranch)"
  }
}
