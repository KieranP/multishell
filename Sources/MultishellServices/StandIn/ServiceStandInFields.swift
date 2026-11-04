import Foundation

/// The keys each kind of stand-in record takes, so one nothing reads, a typo
/// among them, refuses the stand-in rather than being dropped unseen.
enum ServiceStandInFields {
  private static let top: Set = ["pullRequests", "ciRuns"]
  private static let pullRequest: Set = [
    "number", "title", "url", "state", "review", "blocker", "autoMergesWhenReady",
    "isReadyToMerge", "headBranch", "headCommit", "headRepository", "baseBranch", "updatedAt",
    "checks",
  ]
  private static let check: Set = ["name", "workflow", "status", "isRequired", "link"]
  private static let run: Set = [
    "id", "branch", "commit", "subject", "status", "isFinished", "createdAt", "repository",
    "workflows", "failures",
  ]
  private static let workflow: Set = ["name", "status", "jobs"]
  private static let job: Set = ["id", "name", "status"]
  private static let failure: Set = ["workflow", "job", "text"]

  /// What is not an object or a list of them is left to the decoder to refuse.
  static func check(_ data: Data) throws(ServiceStandInUnreadable) {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }
    try refuseUnknownKeys(of: root, allowed: top, at: [])
    try each(root["pullRequests"], at: ["pullRequests"]) {
      record,
      path throws(ServiceStandInUnreadable) in
      try refuseUnknownKeys(of: record, allowed: pullRequest, at: path)
      try each(record["checks"], at: path + ["checks"]) {
        item,
        path throws(ServiceStandInUnreadable) in
        try refuseUnknownKeys(of: item, allowed: check, at: path)
      }
    }
    try each(root["ciRuns"], at: ["ciRuns"]) { record, path throws(ServiceStandInUnreadable) in
      try refuseUnknownKeys(of: record, allowed: run, at: path)
      try each(record["workflows"], at: path + ["workflows"]) {
        item,
        path throws(ServiceStandInUnreadable) in
        try refuseUnknownKeys(of: item, allowed: workflow, at: path)
        try each(item["jobs"], at: path + ["jobs"]) { job, path throws(ServiceStandInUnreadable) in
          try refuseUnknownKeys(of: job, allowed: Self.job, at: path)
        }
      }
      try each(record["failures"], at: path + ["failures"]) {
        item,
        path throws(ServiceStandInUnreadable) in
        try refuseUnknownKeys(of: item, allowed: failure, at: path)
      }
    }
  }

  private static func each(
    _ list: Any?,
    at path: [String],
    _ body: ([String: Any], [String]) throws(ServiceStandInUnreadable) -> Void,
  ) throws(ServiceStandInUnreadable) {
    guard let list = list as? [Any] else { return }
    for (index, item) in list.enumerated() {
      guard let record = item as? [String: Any] else { continue }
      try body(record, path + [String(index)])
    }
  }

  private static func refuseUnknownKeys(
    of record: [String: Any],
    allowed: Set<String>,
    at path: [String],
  ) throws(ServiceStandInUnreadable) {
    guard let unknown = record.keys.sorted().first(where: { !allowed.contains($0) }) else {
      return
    }
    throw ServiceStandInUnreadable(
      at: (path + [unknown]).joined(separator: "."),
      "no stand-in field is named \(unknown)",
    )
  }
}
