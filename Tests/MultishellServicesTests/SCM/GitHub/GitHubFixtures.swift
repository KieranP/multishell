/// What `gh pr list --json` prints. `merged` is real output from this
/// repository; the rest vary one record's fields.
enum GitHubFixtures {
  static let merged = """
    [{"autoMergeRequest":null,"baseRefName":"main","headRefName":"more-highlighting",\
    "headRefOid":"b315c8c4fa48dea06f0c9f19388c0bd949879949","headRepository":{"id":"R_kgDOUOHsXQ",\
    "name":"multishell","nameWithOwner":"KieranP/multishell"},"headRepositoryOwner":{"id":"MDQ6VXNlcjE2NjIw",\
    "name":"Kieran Pilkington","login":"KieranP"},"isCrossRepository":false,"isDraft":false,\
    "mergeStateStatus":"UNKNOWN","mergeable":"UNKNOWN","mergedAt":"2026-10-22T06:25:46Z","number":3,\
    "reviewDecision":"","state":"MERGED","title":"Highlight Svelte, HTML, CSS and SCSS, with embedded code injected",\
    "updatedAt":"2026-10-22T06:25:49Z","url":"https://github.com/KieranP/multishell/pull/3"}]
    """

  static var open: String {
    """
    [\(record(number: 40, reviewDecision: "APPROVED", mergeable: "CONFLICTING", mergeStateStatus: "DIRTY")),
     \(record(number: 42, reviewDecision: "REVIEW_REQUIRED", mergeStateStatus: "BEHIND", autoMerge: true)),
     \(record(number: 41, isDraft: true, mergeStateStatus: "DRAFT")),
     \(record(number: 36, reviewDecision: "CHANGES_REQUESTED", mergeStateStatus: "BLOCKED")),
     \(record(number: 29, state: "CLOSED"))]
    """
  }

  static func record(
    number: Int,
    state: String = "OPEN",
    isDraft: Bool = false,
    reviewDecision: String = "",
    mergeable: String = "MERGEABLE",
    mergeStateStatus: String = "CLEAN",
    autoMerge: Bool = false,
    headRefName: String = "feature",
    headRefOid: String = "abc123",
    owner: String = "KieranP",
  ) -> String {
    let autoMergeRequest =
      autoMerge ? #"{"enabledAt":"2026-10-20T01:00:00Z","mergeMethod":"SQUASH"}"# : "null"
    return """
      {"autoMergeRequest":\(autoMergeRequest),"baseRefName":"main","headRefName":"\(headRefName)",\
      "headRefOid":"\(headRefOid)","headRepository":{"name":"multishell"},\
      "headRepositoryOwner":{"login":"\(owner)"},"isDraft":\(isDraft),\
      "mergeStateStatus":"\(mergeStateStatus)","mergeable":"\(mergeable)","number":\(number),\
      "reviewDecision":"\(reviewDecision)","state":"\(state)","title":"Pull request \(number)",\
      "updatedAt":"2026-10-20T01:00:00Z","url":"https://github.com/KieranP/multishell/pull/\(number)"}
      """
  }
}
