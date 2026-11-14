import Foundation
import MultishellCore
import MultishellGitKit

/// A file with no diff to show, whether git ignores it, and its patches: the
/// read's own batched answers taken where it has them.
extension FileTabReader {
  /// No diff to show: a new file is every line added; one git ignores, or one
  /// unchanged, is shown as it is.
  static func unchangedContent(
    _ text: String,
    path: String,
    in repository: URL,
    against side: CommittedSide,
    git: WorktreeGit,
  ) async -> (FileTabContent, isFileGone: Bool)? {
    var isNew = side.size == nil
    if isNew {
      guard let ignored = await isIgnored(path, in: repository, against: side, git: git)
      else { return nil }
      isNew = !ignored
    }
    let rows = FileTabRows(
      lines: PlainDiffLines.of(text, kind: isNew ? .added : .context),
      marksStaging: side.marksStaging,
    )
    return (.text(rows), false)
  }

  /// Whether git ignores the file, from the read's own check where it made one.
  static func isIgnored(
    _ path: String,
    in repository: URL,
    against side: CommittedSide,
    git: WorktreeGit,
  ) async -> Bool? {
    if let known = side.bases?.isIgnored(path) { return known }
    return await git.ignoredPaths([path], in: repository)?.contains(path)
  }

  /// The read's patches diffed up front where it made them, else git's for this file.
  static func patches(
    of path: String,
    in repository: URL,
    since commit: String?,
    against side: CommittedSide,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FilePatches? {
    if let diffed = side.bases?.patches(of: path, since: commit) { return diffed }
    return await git.patches(
      of: path,
      in: repository,
      diffAlgorithm: diffAlgorithm,
      since: commit,
      knownBase: side.bases?.headOrEmptyTree,
    )
  }
}
