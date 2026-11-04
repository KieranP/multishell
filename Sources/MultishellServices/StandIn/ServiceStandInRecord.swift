import Foundation

/// A stand-in's JSON, keyed as the domain types name their fields and their raw
/// values, which is what `worktrees show` prints.
struct ServiceStandInRecord: Decodable {
  struct PullRequestRecord: Decodable {
    let number: Int
    let title: String
    let url: URL?
    let state: PullRequestState
    let review: PullRequestReview?
    let blocker: PullRequestBlocker?
    let autoMergesWhenReady: Bool?
    let isReadyToMerge: Bool?
    let headBranch: String
    let headCommit: String
    let headRepository: RepositoryRecord
    let baseBranch: String?
    let updatedAt: Date?
    let checks: [CheckRecord]?

    /// Its page on GitHub where no `url` is given, the slot it fills being GitHub's.
    /// Undated is the oldest, as an undated run is, which only orders them.
    var pullRequest: PullRequest {
      let repository = headRepository.repository
      let page = URL(
        string: "https://github.com/\(repository.owner)/\(repository.name)/pull/\(number)"
      )
      return PullRequest(
        number: number,
        title: title,
        url: url ?? page ?? URL(filePath: "/"),
        state: state,
        review: review ?? .notRequired,
        blocker: blocker,
        hasConflictAnswer: true,
        autoMergesWhenReady: autoMergesWhenReady ?? false,
        isReadyToMerge: isReadyToMerge ?? false,
        headBranch: headBranch,
        headCommit: headCommit,
        headRepository: headRepository.repository,
        baseBranch: baseBranch ?? "main",
        updatedAt: updatedAt ?? .distantPast,
      )
    }
  }

  /// A remote's URL, or `owner/name`, refused where it names neither: a path,
  /// relative or not, or a file URL.
  struct RepositoryRecord: Decodable {
    let repository: RemoteRepository

    init(from decoder: any Decoder) throws {
      let text = try decoder.singleValueContainer().decode(String.self)
      let steps = text.split(separator: "/", omittingEmptySubsequences: false)
      let isOwnerAndName =
        !text.contains(":") && steps.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
      guard
        let repository = RemoteRepository(remoteURL: text)
          ?? (isOwnerAndName ? RemoteRepository(remoteURL: "https://host/\(text)") : nil)
      else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "\(text) names no owner/name")
        )
      }
      self.repository = repository
    }
  }

  struct CheckRecord: Decodable {
    let name: String
    let workflow: String?
    let status: CIRunStatus
    let isRequired: Bool?
    let link: URL?

    var check: PullRequestCheck {
      PullRequestCheck(
        name: name,
        workflow: workflow,
        status: status,
        isRequired: isRequired ?? false,
        link: link,
      )
    }
  }

  struct RunRecord: Decodable {
    let id: String
    let branch: String
    let commit: String
    let subject: String?
    let status: CIRunStatus
    let isFinished: Bool?
    let createdAt: Date?
    /// Where it ran; `nil` matches whichever project asks.
    let repository: RepositoryRecord?
    let workflows: [WorkflowRecord]?
    let failures: [FailureRecord]?

    /// Finished unless running or on hold, where none is given.
    var run: CIRun {
      CIRun(
        id: id,
        branch: branch,
        commit: commit,
        subject: subject,
        status: status,
        isFinished: isFinished ?? !(status == .running || status == .onHold),
        createdAt: createdAt,
        repository: repository?.repository,
      )
    }
  }

  struct WorkflowRecord: Decodable {
    let name: String
    let status: CIRunStatus
    let jobs: [JobRecord]?

    var workflow: CIWorkflow {
      CIWorkflow(
        name: name,
        status: status,
        jobs: (jobs ?? []).map { CIJob(id: $0.id, name: $0.name, status: $0.status) },
      )
    }
  }

  struct JobRecord: Decodable {
    let id: String?
    let name: String
    let status: CIRunStatus
  }

  struct FailureRecord: Decodable {
    let workflow: String?
    let job: String?
    let text: String

    var excerpt: CIFailureExcerpt { CIFailureExcerpt(workflow: workflow, job: job, text: text) }
  }

  let pullRequests: [PullRequestRecord]?
  let ciRuns: [RunRecord]?
}
