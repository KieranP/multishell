import Foundation
import MultishellCore
import MultishellProcess

extension Helper {
  private static let sampleFollowInterval: Duration = .milliseconds(500)
  /// Asked for each look while following: a sample lands each second.
  private static let sampleFollowLook = 2
  /// Asked again where a look missed some: more than a stalled second lands.
  private static let sampleFollowWindow = 30
  /// What `--summary` covers unless told: a minute.
  private static let summaryWindow = 60

  /// `--follow` prints each new sample as it lands, one JSON object a line,
  /// until `--count` of them or an interrupt.
  static func runDebugSamples(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = "debug"
    let options = try CommandOptions(
      arguments,
      valued: ["last", "count"],
      flags: ["follow", "summary"],
      topic: topic,
    )
    let last = try options.count("last")
    let stopAfter = try options.count("count")
    if options.has("summary") {
      guard !options.has("follow"), stopAfter == nil else {
        throw UsageError(
          "--summary sums up past samples; --follow and --count go together",
          topic: topic,
        )
      }
      return try ask(.debugSummary(last: last ?? summaryWindow), environment: environment)
    }
    guard options.has("follow") else {
      guard stopAfter == nil else { throw UsageError("--count goes with --follow", topic: topic) }
      return try ask(.debugSamples(last: last ?? 1), environment: environment)
    }
    try followSamples(after: last, stopAfter: stopAfter, environment: environment)
    return 0
  }

  /// The newest `last` first where asked, then each new one as it lands.
  private static func followSamples(
    after last: Int?,
    stopAfter: Int?,
    environment: [String: String],
  ) throws {
    let backlog = try samples(last: last ?? 1, environment: environment)
    if last != nil {
      for sample in backlog { print(sample.line) }
      fflush(stdout)
    }
    var newest = backlog.last?.sequence ?? -1
    var printed = 0
    while stopAfter.map({ printed < $0 }) ?? true {
      Thread.sleep(forTimeInterval: sampleFollowInterval.inSeconds)
      var looked = try samples(last: sampleFollowLook, environment: environment)
      if let oldest = looked.first?.sequence, oldest > newest + 1 {
        looked = try samples(last: sampleFollowWindow, environment: environment)
      }
      let fresh =
        looked
        .filter { $0.sequence > newest }
        .prefix(stopAfter.map { $0 - printed } ?? .max)
      for sample in fresh {
        print(sample.line)
        fflush(stdout)
        newest = sample.sequence
        printed += 1
      }
    }
  }

  /// Each as its number and one line of JSON, keys sorted as the app sends them.
  private static func samples(
    last: Int,
    environment: [String: String],
  ) throws -> [(sequence: Int, line: String)] {
    let text = try output(of: .debugSamples(last: last), environment: environment) ?? "[]"
    let records = jsonValue(text) as? [[String: Any]]
    return (records ?? []).compactMap { record in
      guard let sequence = record["sequence"] as? Int,
        let data = try? JSONSerialization.data(
          withJSONObject: record,
          options: [.sortedKeys, .withoutEscapingSlashes],
        )
      else { return nil }
      return (sequence, String(decoding: data, as: UTF8.self))
    }
  }
}
