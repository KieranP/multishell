import Foundation
import MultishellCore

/// One element of `gh pr checks --json`, every field optional as
/// `GitHubPullRequestRecord`'s.
struct GitHubCheckRecord: Decodable {
  /// The fields asked for, and so the ones `gh` prints.
  static let fields = ["name", "workflow", "bucket", "link"]

  let name: String?
  let workflow: String?
  /// `gh`'s own sorting of `state`: pass, fail, pending, skipping or cancel.
  let bucket: String?
  let link: String?

  private var key: CheckKey? {
    name.map { CheckKey(workflow: workflow?.trimmedOrNil, name: $0) }
  }

  /// A rerun's job sits at a higher number in its link, `…/job/119668904437`.
  private var jobNumber: Int {
    link.flatMap { URL(string: $0)?.lastPathComponent }.flatMap { Int($0) } ?? 0
  }

  private var status: CIRunStatus? {
    switch bucket {
    case "pass": .passed
    case "fail": .failed
    case "pending": .running
    case "skipping", "cancel": .cancelled
    default: nil
    }
  }

  /// Each check once, its newest run kept: `gh` lists a rerun beside the run it
  /// replaced. `required` is what `--required` listed, by workflow and name.
  static func checks(from json: Data, required: Set<CheckKey>) throws -> [PullRequestCheck] {
    var newest: [CheckKey: (order: Int, record: Self)] = [:]
    for record in try records(from: json) {
      guard let key = record.key else { continue }
      if let kept = newest[key], kept.record.jobNumber >= record.jobNumber { continue }
      newest[key] = (newest[key]?.order ?? newest.count, record)
    }
    return newest.sorted { $0.value.order < $1.value.order }.compactMap { key, entry in
      entry.record.check(isRequired: required.contains(key))
    }
  }

  /// The workflow and name `--required` answered with.
  static func keys(from json: Data) throws -> Set<CheckKey> {
    Set(try records(from: json).compactMap(\.key))
  }

  private static func records(from json: Data) throws -> [Self] {
    try ToolAnswer.decode(LossyArray<Self>.self, from: json).elements
  }

  private func check(isRequired: Bool) -> PullRequestCheck? {
    guard let name, let status else { return nil }
    return PullRequestCheck(
      name: name,
      workflow: workflow?.trimmedOrNil,
      status: status,
      isRequired: isRequired,
      link: link.flatMap(URL.init(string:)),
    )
  }
}
