import Foundation

/// Parses `git for-each-ref` with refname, objectname, upstream,
/// upstream:track and symref, tab separated.
///
/// Tab separated because a ref name may hold anything but a tab, and the
/// track field holds spaces and commas. A row missing its first two fields
/// is dropped rather than costing the whole read: this runs on a poll, and
/// one odd ref should not blank every badge. Pure, so the format is tested
/// against fixture text.
public enum BranchRefParser {
  public static func parse(_ output: String) -> [BranchRef] {
    output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
      .compactMap { row(from: $0) }
  }

  private static func row(from line: Substring) -> BranchRef? {
    // Trailing \r where git ran with a Windows-configured core.autocrlf.
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
    guard fields.count >= 2 else { return nil }
    let name = fields[0]
    let tip = fields[1]
    guard !name.isEmpty, !tip.isEmpty else { return nil }
    let upstream = fields.count > 2 && !fields[2].isEmpty ? fields[2] : nil
    let track = fields.count > 3 ? fields[3] : ""
    let symref = fields.count > 4 && !fields[4].isEmpty ? fields[4] : nil
    return BranchRef(
      fullName: name, tip: tip, upstream: upstream,
      isUpstreamGone: upstream != nil && track.contains("gone"), symref: symref)
  }
}
