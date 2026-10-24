/// What a file tab diffs the file on disk against: a commit, `HEAD` where `nil`,
/// the file's size there, and whether a changed line says staged or unstaged.
struct CommittedSide {
  let commit: String?
  let size: Int?
  /// Not against an older commit than `HEAD`, whose changes the index holds too.
  let marksStaging: Bool
}
