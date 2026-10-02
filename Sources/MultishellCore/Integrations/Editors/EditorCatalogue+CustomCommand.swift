import Foundation

extension EditorCatalogue {
  /// The user's template with `{path}` read from the environment. One
  /// without the placeholder gets the path appended.
  public static func customCommandLine(_ template: String, path: URL) -> ShellLine? {
    let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let token = "{path}"
    let line = trimmed.contains(token) ? trimmed : "\(trimmed) \(token)"
    return ShellLine(
      line, substituting: [token: (WorktreePlaceholder.worktreePath.variable, path.path)])
  }
}
