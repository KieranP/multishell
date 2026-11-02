import Foundation
import MultishellCore

/// One element of `gh pr list --json`, every field optional: a field a
/// newer gh drops or retypes costs that pull request, not the list.
struct GitHubPullRequestRecord: Decodable {
  struct Owner: Decodable {
    let login: String?
  }

  struct Repository: Decodable {
    let name: String?
  }

  /// The fields asked for, and so the ones `gh` prints.
  static let fields = [
    "number", "title", "url", "state", "isDraft", "reviewDecision", "mergeStateStatus",
    "mergeable", "autoMergeRequest", "headRefName", "headRefOid", "headRepository",
    "headRepositoryOwner", "baseRefName", "updatedAt",
  ]

  /// GitHub merges these at a click. UNSTABLE also merges, but past a failing
  /// check, so it is not called ready.
  private static let readyMergeStates: Set = ["CLEAN", "HAS_HOOKS"]

  let number: Int?
  let title: String?
  let url: String?
  let state: String?
  let isDraft: Bool?
  let reviewDecision: String?
  let mergeStateStatus: String?
  let mergeable: String?
  /// `null` while auto-merge is off; its contents are not read.
  let autoMergeRequest: JSONValue?
  let headRefName: String?
  let headRefOid: String?
  let headRepository: Repository?
  let headRepositoryOwner: Owner?
  let baseRefName: String?
  let updatedAt: Date?

  /// `nil` where a field the row needs is missing or names a state this
  /// build does not know.
  var pullRequest: PullRequest? {
    guard let number, let title, let url = url.flatMap(URL.init(string:)),
      let state = pullRequestState, let headRefName, let headRefOid,
      let owner = headRepositoryOwner?.login, let name = headRepository?.name,
      let baseRefName, let updatedAt
    else { return nil }
    return PullRequest(
      number: number,
      title: title,
      url: url,
      state: state,
      review: review,
      blocker: blocker,
      hasConflictAnswer: blocker == .conflicts || mergeable != "UNKNOWN",
      autoMergesWhenReady: autoMergeRequest != nil,
      isReadyToMerge: isReadyToMerge(as: state),
      headBranch: headRefName,
      headCommit: headRefOid,
      headRepository: RemoteRepository(owner: owner, name: name),
      baseBranch: baseRefName,
      updatedAt: updatedAt,
    )
  }

  private var pullRequestState: PullRequestState? {
    switch state {
    case "OPEN": isDraft == true ? .draft : .open
    case "CLOSED": .closed
    case "MERGED": .merged
    default: nil
    }
  }

  private var review: PullRequestReview {
    switch reviewDecision {
    case "APPROVED": .approved
    case "CHANGES_REQUESTED": .changesRequested
    case "REVIEW_REQUIRED": .required
    default: .notRequired
    }
  }

  /// GitHub works the merge state out lazily and answers `UNKNOWN` until it
  /// has, so a conflict is taken from either field.
  private var blocker: PullRequestBlocker? {
    if mergeable == "CONFLICTING" || mergeStateStatus == "DIRTY" { return .conflicts }
    switch mergeStateStatus {
    case "BEHIND": return .behindBase
    case "BLOCKED": return .blocked
    default: return nil
    }
  }

  /// Each record that names everything the row needs; one that does not
  /// costs itself. Output that is not a JSON array fails the read.
  static func pullRequests(from json: Data) throws -> [PullRequest] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try ToolAnswer.decode(LossyArray<Self>.self, from: json, with: decoder).elements
      .compactMap(\.pullRequest)
  }

  /// Either field may be the first to see a conflict, as for `blocker`.
  private func isReadyToMerge(as state: PullRequestState) -> Bool {
    state == .open && blocker == nil && Self.readyMergeStates.contains(mergeStateStatus ?? "")
  }
}
