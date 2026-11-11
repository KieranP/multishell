import Foundation

extension EditorCatalogue {
  /// The user's template with `{path}` read from the environment. One
  /// without the placeholder gets the path appended.
  public static func customCommandLine(
    _ template: String,
    target: EditorTarget,
    forShellNamed shellName: String,
  ) -> ShellLine? {
    guard let trimmed = template.trimmedOfAllWhitespaceOrNil else { return nil }
    let token = "{path}"
    let line = EditorTemplate.placing(token, in: trimmed)
    return ShellLine(
      line,
      substituting: [token: (target.pathVariable, target.path.path)],
      forShellNamed: shellName,
    )
  }
}
