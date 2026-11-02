import Foundation
import MultishellCore

/// One element of `circleci run list --json`, and `run get`'s answer, which
/// adds the workflows. Every field optional, as `GitHubPullRequestRecord`'s.
struct CircleCIRunRecord: Decodable {
  struct Workflow: Decodable {
    let name: String?
    let phase: String?
    let outcome: String?
    let currentOutcome: String?
    let jobs: LossyArray<Job>?
  }

  struct Commit: Decodable {
    let subject: String?
  }

  struct Job: Decodable {
    let id: String?
    let name: String?
    let phase: String?
    let outcome: String?
    let currentOutcome: String?
  }

  let id: String?
  let phase: String?
  let outcome: String?
  let currentOutcome: String?
  /// `nil` for a run of a tag, which no worktree's branch is.
  let branch: String?
  let revision: String?
  let commit: Commit?
  /// Read as text, so a time this build cannot parse costs the time alone.
  let createdAt: String?
  let repositoryUrl: String?
  let workflows: LossyArray<Workflow>?

  /// `nil` where a field the row needs is missing. A status in words this
  /// build does not know is `.unknown`, so the run before it is not shown.
  var run: CIRun? {
    guard let id, let branch, let revision else { return nil }
    let status = Self.status(phase, outcome, currentOutcome)
    return CIRun(
      id: id,
      branch: branch,
      commit: revision,
      subject: commit?.subject?.trimmedOrNil,
      status: status,
      isFinished: CircleCIStatusWords.isFinished(phase: phase, status: status),
      createdAt: createdAt.flatMap(CircleCITimestamp.date(from:)),
      repository: repositoryUrl.flatMap(RemoteRepository.init(remoteURL:)),
    )
  }

  /// Every workflow and job with a name; a word neither list knows is
  /// `.unknown`, as a run's is, rather than guessed.
  var ciWorkflows: [CIWorkflow] {
    (workflows?.elements ?? []).compactMap { workflow in
      guard let name = workflow.name else { return nil }
      let jobs = (workflow.jobs?.elements ?? []).compactMap { job in
        job.name.map { name in
          CIJob(
            id: job.id,
            name: name,
            status: Self.status(job.phase, job.outcome, job.currentOutcome),
          )
        }
      }
      return CIWorkflow(
        name: name,
        status: Self.status(workflow.phase, workflow.outcome, workflow.currentOutcome),
        jobs: jobs,
      )
    }
  }

  private static func status(
    _ phase: String?,
    _ outcome: String?,
    _ currentOutcome: String?,
  ) -> CIRunStatus {
    CircleCIStatusWords.status(phase: phase, outcome: outcome, currentOutcome: currentOutcome)
      ?? .unknown
  }

  /// `run list`'s answer, `null` being Go's empty list. Output that is not a
  /// JSON array fails the read.
  static func runs(from json: Data) throws -> [CIRun] {
    (try decoded(LossyArray<Self>?.self, from: json))?.elements.compactMap(\.run) ?? []
  }

  /// `run get`'s answer, one run with its workflows.
  static func workflows(from json: Data) throws -> [CIWorkflow] {
    try decoded(Self.self, from: json).ciWorkflows
  }

  private static func decoded<Value: Decodable>(
    _ type: Value.Type,
    from json: Data,
  ) throws -> Value {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try ToolAnswer.decode(type, from: json, with: decoder)
  }
}
