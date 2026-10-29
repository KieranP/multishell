import Foundation
import MultishellCore

/// The answer to `query`: what the repository allows, the method GitHub's
/// merge box opens on for this user, and GitHub's own message for each.
struct GitHubMergeOptionsRecord: Decodable {
  /// The answer's `data`; `gh` exits non-zero for any `errors` beside it.
  struct Envelope: Decodable {
    struct Answer: Decodable {
      let repository: GitHubMergeOptionsRecord?
    }

    let data: Answer?
  }

  struct PullRequestRecord: Decodable {
    let mergeHeadline: String?
    let mergeBody: String?
    let squashHeadline: String?
    let squashBody: String?
  }

  /// Asked of the repository the pull request's page names; the aliases give
  /// each method's message a name.
  static let query = """
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        mergeCommitAllowed squashMergeAllowed rebaseMergeAllowed autoMergeAllowed
        viewerPermission viewerDefaultMergeMethod
        pullRequest(number: $number) {
          mergeHeadline: viewerMergeHeadlineText(mergeType: MERGE)
          mergeBody: viewerMergeBodyText(mergeType: MERGE)
          squashHeadline: viewerMergeHeadlineText(mergeType: SQUASH)
          squashBody: viewerMergeBodyText(mergeType: SQUASH)
        }
      }
    }
    """

  /// GitHub's roles that may not push to the base, and so not merge into it.
  /// Any other, or none answered, is left for GitHub itself to refuse.
  private static let readingPermissions: Set = ["READ", "TRIAGE"]

  let mergeCommitAllowed: Bool?
  let squashMergeAllowed: Bool?
  let rebaseMergeAllowed: Bool?
  let autoMergeAllowed: Bool?
  let viewerPermission: String?
  let viewerDefaultMergeMethod: String?
  let pullRequest: PullRequestRecord?

  private var mergeOptions: PullRequestMergeOptions? {
    let methods = PullRequestMergeMethod.offered.filter(allows)
    guard let first = methods.first, let pullRequest else { return nil }
    let preferred = viewerDefaultMergeMethod.flatMap(Self.method(named:))
    var messages: [PullRequestMergeMethod: PullRequestMergeMessage] = [:]
    messages[.merge] = Self.message(pullRequest.mergeHeadline, pullRequest.mergeBody)
    messages[.squash] = Self.message(pullRequest.squashHeadline, pullRequest.squashBody)
    return PullRequestMergeOptions(
      methods: methods,
      defaultMethod: preferred.flatMap { methods.contains($0) ? $0 : nil } ?? first,
      messages: messages,
      allowsAutoMerge: autoMergeAllowed == true,
      viewerMayMerge: !Self.readingPermissions.contains(viewerPermission ?? ""),
    )
  }

  /// Output naming no allowed method or no pull request fails the read.
  static func options(from json: Data) throws -> PullRequestMergeOptions {
    let envelope = try ToolAnswer.decode(Envelope.self, from: json)
    guard let record = envelope.data?.repository, let options = record.mergeOptions else {
      throw ServiceReadFailure.failed(t("integration.unreadable-answer"))
    }
    return options
  }

  /// None where GitHub wrote no headline; a missing body is an empty one.
  private static func message(_ headline: String?, _ body: String?) -> PullRequestMergeMessage? {
    headline.map { PullRequestMergeMessage(subject: $0, body: body ?? "") }
  }

  private static func method(named name: String) -> PullRequestMergeMethod? {
    switch name {
    case "MERGE": .merge
    case "SQUASH": .squash
    case "REBASE": .rebase
    default: nil
    }
  }

  private func allows(_ method: PullRequestMergeMethod) -> Bool {
    switch method {
    case .merge: mergeCommitAllowed == true
    case .rebase: rebaseMergeAllowed == true
    case .squash: squashMergeAllowed == true
    }
  }
}
