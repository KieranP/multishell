import Foundation

extension WorktreeSettings {
  /// Applies `branchPrefix`, without doubling it if the user typed it.
  public func qualifiedBranch(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !branchPrefix.isEmpty, !trimmed.hasPrefix(branchPrefix) else { return trimmed }
    return branchPrefix + trimmed
  }
}
