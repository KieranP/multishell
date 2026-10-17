import Foundation
import MultishellCore
import MultishellGitKit

/// Reads one file tab's file and its changes against `HEAD`; see
/// Docs/design/files.md.
enum FileTabReader {
  /// The spikes: git diffs 1 MiB in under 40 ms, but the forced TextKit 2
  /// view takes up to 186 MB laid out at that size.
  static let sizeLimit = 1 << 20

  /// `previous` is the tab's last read, which a file deleted under an open
  /// tab keeps showing, unmarked.
  static func read(
    path pathInWorktree: String,
    in worktree: URL,
    git: WorktreeGit,
    diffAlgorithm: DiffAlgorithm,
    previous: FileTabReading?,
  ) async -> FileTabReading {
    let url = worktree.appending(path: pathInWorktree)
    let (onDisk, repository) = await runOnDispatch {
      (
        FileOnDisk.read(url, sizeLimit: sizeLimit),
        RepositoryLocation.innermost(holding: pathInWorktree, in: worktree),
      )
    }
    // A file in a submodule is diffed against the submodule's own `HEAD`.
    let path = repository.path
    let committedSize = try? await git.committedSize(of: path, in: repository.directory)
    if case .gone = onDisk {
      // A tab that showed the file keeps its last text; one showing `HEAD`'s
      // removed lines reads `HEAD` again, a commit being able to move it.
      if case .text(let rows) = previous?.content, previous?.isFileGone == false,
        rows.holdsTextOnDisk
      {
        return FileTabReading(content: .text(rows.lastTextOnDisk()), isFileGone: true)
      }
      if let previous, previous.isFileGone, case .text(let rows) = previous.content,
        !rows.lines.contains(where: { $0.kind == .removed })
      {
        return previous
      }
      guard let committedSize else { return FileTabReading(content: .missing, isFileGone: true) }
      guard committedSize <= sizeLimit else {
        return FileTabReading(content: .tooLarge(bytes: committedSize), isFileGone: true)
      }
    }
    if let committedSize, committedSize > sizeLimit {
      return FileTabReading(content: .tooLarge(bytes: committedSize), isFileGone: false)
    }
    switch onDisk {
    case .tooLarge(let bytes):
      return FileTabReading(content: .tooLarge(bytes: bytes), isFileGone: false)

    case .gone:
      let content = await deletedContent(
        path: path,
        in: repository.directory,
        committedSize: committedSize,
        git: git,
        diffAlgorithm,
      )
      return FileTabReading(content: content, isFileGone: true)

    case .bytes(let data):
      let content = await content(
        of: data,
        path: path,
        in: repository.directory,
        isTracked: committedSize != nil,
        git: git,
        diffAlgorithm,
      )
      return FileTabReading(content: content, isFileGone: false)
    }
  }

  /// `HEAD`'s text, every line removed.
  private static func deletedContent(
    path: String,
    in repository: URL,
    committedSize: Int?,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FileTabContent {
    guard let patches = await git.patches(of: path, in: repository, diffAlgorithm: diffAlgorithm)
    else { return .missing }
    // The patch holds the committed bytes, so it is guessed as the file would be.
    let encoding = TextDecoding.decode(patches.onDisk)?.encoding ?? .utf8
    switch UnifiedPatchParser.parse(patches.onDisk, encoding: encoding) {
    case .binary: return .binary(bytes: committedSize ?? 0)
    case .lines(let lines): return .text(FileTabRows(lines: lines))
    case .modeOnly, .unchanged: return .missing
    }
  }

  /// A file with no committed side and nothing staged is untracked: every
  /// line added, no git needed beyond what said so.
  private static func content(
    of data: Data,
    path: String,
    in repository: URL,
    isTracked: Bool,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FileTabContent {
    guard let (text, encoding) = TextDecoding.decode(data) else {
      return .binary(bytes: data.count)
    }
    let patches = await git.patches(of: path, in: repository, diffAlgorithm: diffAlgorithm)
    let onDiskPatch = patches.map { UnifiedPatchParser.parse($0.onDisk, encoding: encoding) }
    switch onDiskPatch ?? .unchanged {
    case .binary:
      return .binary(bytes: data.count)

    case .lines(let lines):
      let staged = patches.map { UnifiedPatchParser.parse($0.staged, encoding: encoding) }
      guard case .lines(let stagedLines) = staged else { return .text(FileTabRows(lines: lines)) }
      return .text(FileTabRows(lines: StagedChangeMarker.marking(lines, stagedIn: stagedLines)))

    case .modeOnly:
      return .text(FileTabRows(lines: plainLines(text, kind: .context), hasModeChange: true))

    case .unchanged:
      // A new file is every line added; one git ignores is shown as it is.
      var isNew = !isTracked
      if isNew { isNew = await git.ignoredPaths([path], in: repository)?.contains(path) == false }
      return .text(FileTabRows(lines: plainLines(text, kind: isNew ? .added : .context)))
    }
  }

  /// One row per line, a final newline closing the last rather than opening
  /// another.
  private static func plainLines(_ text: String, kind: DiffLine.Kind) -> [DiffLine] {
    var parts = text.lines()
    if parts.last?.isEmpty == true { parts.removeLast() }
    return parts.enumerated().map { index, part in
      let line = String(part)
      let number = index + 1
      return DiffLine(
        kind: kind,
        oldNumber: kind == .context ? number : nil,
        newNumber: number,
        text: line,
      )
    }
  }
}
