import MultishellGitKit

/// What the agent is asked. English whatever the app's language: it is read
/// by a model, never shown; see Docs/design/translation.md.
enum AutoRenamePrompt {
  /// The branch is the read's own, the sidebar's listing lagging a checkout.
  static func text(for material: RenameMaterial) -> String {
    var sections = [
      """
      Name the work on the git branch below in two to five words, for a list of \
      branches in a sidebar. Say what the work does, not how. Reply with the name \
      alone on one line: no quotes, no markdown, no full stop, nothing else. Do not \
      use any tool.
      """,
      "Branch: \(material.branch ?? "none, HEAD is detached")",
    ]
    if !material.subjects.isEmpty {
      sections.append(
        "Commit subjects, newest first:\n"
          + material.subjects.map { "- \($0)" }.joined(separator: "\n")
      )
    }
    if !material.diffstat.isEmpty {
      sections.append("Files changed:\n\(material.diffstat)")
    }
    if !material.diff.isEmpty {
      let heading = material.isDiffCut ? "The diff, cut short:" : "The diff:"
      sections.append("\(heading)\n\(material.diff)")
    }
    return sections.joined(separator: "\n\n")
  }
}
