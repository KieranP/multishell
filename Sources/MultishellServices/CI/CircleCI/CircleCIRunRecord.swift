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

  /// `nil` where a field the row needs is missing or its status is a word
  /// this build does not know.
  var run: CIRun? {
    guard let id, let branch, let revision,
      let status = CircleCIStatusWords.status(
        phase: phase,
        outcome: outcome,
        currentOutcome: currentOutcome,
      )
    else { return nil }
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

  /// Every workflow and job with a name and a status this build knows; a word
  /// neither list knows is left out, as a run's is, rather than guessed.
  var ciWorkflows: [CIWorkflow] {
    (workflows?.elements ?? []).compactMap { workflow in
      guard let name = workflow.name,
        let status = CircleCIStatusWords.status(
          phase: workflow.phase,
          outcome: workflow.outcome,
          currentOutcome: workflow.currentOutcome,
        )
      else { return nil }
      let jobs = (workflow.jobs?.elements ?? []).compactMap { job in
        job.name.flatMap { name in
          CircleCIStatusWords.status(
            phase: job.phase,
            outcome: job.outcome,
            currentOutcome: job.currentOutcome,
          ).map { status in
            CIJob(id: job.id, name: name, status: status)
          }
        }
      }
      return CIWorkflow(name: name, status: status, jobs: jobs)
    }
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
