import Foundation

extension WorktreeSettings {
  /// `name` trimmed and given `prefix`, unless it already starts with it.
  public static func qualifiedBranch(_ name: String, prefix: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !prefix.isEmpty, trimmed.removingPrefix(prefix) == nil else { return trimmed }
    return prefix + trimmed
  }

  /// Applies `branchPrefix`, without doubling it if the user typed it.
  public func qualifiedBranch(_ name: String) -> String {
    Self.qualifiedBranch(name, prefix: branchPrefix)
  }
}
