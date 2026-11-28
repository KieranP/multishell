import Foundation

extension WorktreeSettings {
  /// As creation applies them: a space typed into a field would otherwise
  /// reach the branch name or path.
  public var trimmed: Self {
    Self(
      worktreeDirectory: worktreeDirectory.trimmingCharacters(in: .whitespaces),
      branchPrefix: branchPrefix.trimmingCharacters(in: .whitespaces),
    )
  }
}
