import Foundation

/// Parses `git for-each-ref`, tab separated because a ref name may hold
/// anything else. A row missing its first two fields is dropped.
enum BranchRefParser {
  static func parse(_ output: String) -> [BranchRef] {
    output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
      .compactMap { ref(from: $0) }
  }

  private static func ref(from line: Substring) -> BranchRef? {
    // Trailing \r where git ran with a Windows-configured core.autocrlf.
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
    guard fields.count >= 2 else { return nil }
    let name = fields[0]
    let tip = fields[1]
    guard !name.isEmpty, !tip.isEmpty else { return nil }
    func field(_ index: Int) -> String? {
      fields.count > index && !fields[index].isEmpty ? fields[index] : nil
    }
    let upstreamRef = field(2)
    let track = field(3) ?? ""
    // Seconds since the epoch. A field missing or not a number is no date
    // rather than a dropped row; the badges do not read it.
    let committed = field(5).flatMap(TimeInterval.init)
    return BranchRef(
      fullName: name,
      tip: tip,
      upstreamIsGone: upstreamRef != nil && track.contains("gone"),
      upstreamRef: upstreamRef,
      upstreamRemote: field(6),
      upstreamBranch: field(7).map(RefName.shortLocal),
      pushRemote: field(8),
      symref: field(4),
      committedAt: committed.map(Date.init(timeIntervalSince1970:)),
    )
  }
}
