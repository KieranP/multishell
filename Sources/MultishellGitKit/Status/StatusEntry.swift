import MultishellCore

/// One path of `git status --porcelain=v1 -z`: the index's letter, the working
/// tree's and the path.
struct StatusEntry: Equatable, Sendable {
  let indexState: Character
  let workTreeState: Character
  let path: String

  var isUntracked: Bool { indexState == "?" }

  var isUnmerged: Bool {
    switch (indexState, workTreeState) {
    case ("U", _), (_, "U"), ("A", "A"), ("D", "D"): true
    default: false
    }
  }

  var isStaged: Bool { indexState != " " && !isUntracked }

  /// Under Staged Only the index's letter alone says what happened.
  func changeKind(counting indicator: GitStatusIndicator) -> StatusChange.Kind {
    if indicator == .stagedOnly {
      return indexState == "A" ? .added : indexState == "D" ? .deleted : .modified
    }
    if workTreeState == "D" || (indexState == "D" && workTreeState == " ") { return .deleted }
    // ` A` is `git add -N`: in the index with no content yet, every line new.
    return indexState == "A" || workTreeState == "A" ? .added : .modified
  }
}
