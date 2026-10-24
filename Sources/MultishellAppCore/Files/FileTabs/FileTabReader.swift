import Foundation
import MultishellCore
import MultishellGitKit

/// Reads one file tab's file and its changes against `HEAD`, or where its
/// branch left `base`; see Docs/design/files.md.
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
    since base: DefaultBranch?,
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
    // A file too large on disk is said so before git is asked anything.
    let data: Data?
    switch onDisk {
    case .bytes(let bytes): data = bytes
    case .gone: data = nil

    case .tooLarge(let bytes):
      return FileTabReading(content: .tooLarge(bytes: bytes), isFileGone: false)
    }
    let isGone = data == nil
    if isGone, let kept = keptReading(ofGoneFile: previous) { return kept }
    let resolved = await committedSide(
      of: repository,
      in: worktree,
      since: base,
      isGone: isGone,
      git: git,
    )
    guard let side = resolved else {
      // What it counts from is unknown: the last rows, else none rather than a guess.
      if let previous, case .text = previous.content, previous.isFileGone == isGone {
        return previous
      }
      return FileTabReading(content: .unreadable, isFileGone: isGone)
    }
    let committedSize = side.size
    if isGone, let notice = noticeOfGoneFile(committedSize: committedSize) { return notice }
    if let committedSize, committedSize > sizeLimit {
      return FileTabReading(content: .tooLarge(bytes: committedSize), isFileGone: false)
    }
    guard let data else {
      let content = await deletedContent(
        path: path,
        in: repository.directory,
        against: side,
        git: git,
        diffAlgorithm,
      )
      return FileTabReading(content: content, isFileGone: true)
    }
    let content = await content(
      of: data,
      path: path,
      in: repository.directory,
      against: side,
      git: git,
      diffAlgorithm,
    )
    return FileTabReading(content: content, isFileGone: false)
  }

  /// What a tab whose file is gone keeps showing without asking git, `nil` where
  /// its committed copy is read.
  private static func keptReading(ofGoneFile previous: FileTabReading?) -> FileTabReading? {
    // A tab that showed the file keeps its last text; one showing the committed
    // side's removed lines reads it again, a commit being able to move it.
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
    return nil
  }

  /// A gone file with no committed copy to show removed, or one too large.
  private static func noticeOfGoneFile(committedSize: Int?) -> FileTabReading? {
    guard let committedSize else { return FileTabReading(content: .missing, isFileGone: true) }
    guard committedSize <= sizeLimit else {
      return FileTabReading(content: .tooLarge(bytes: committedSize), isFileGone: true)
    }
    return nil
  }

  /// The merge base with `base` for the worktree's own file, else `HEAD`; `nil`
  /// where git cannot say which.
  private static func committedSide(
    of repository: RepositoryLocation,
    in worktree: URL,
    since base: DefaultBranch?,
    isGone: Bool,
    git: WorktreeGit,
  ) async -> CommittedSide? {
    var commit: String?
    if let base, repository.directory == worktree {
      async let mergeBase = git.mergeBase(with: base, inRepositoryAt: worktree)
      async let head = git.headCommit(in: worktree)
      // No shared history is an answer, `HEAD`; only a throw leaves git unable to say.
      do {
        commit = try await mergeBase
      } catch {
        return nil
      }
      // On the base itself the index holds nothing past `HEAD`, so its marks stay exact.
      if let found = commit, found == (await head) { commit = nil }
    }
    // A size git could not read is no answer, not a file the merge base lacks.
    let size: Int?
    do {
      size = try await git.committedSize(of: repository.path, in: repository.directory, at: commit)
    } catch {
      return nil
    }
    guard commit != nil, size == nil, isGone else {
      return CommittedSide(commit: commit, size: size, marksStaging: commit == nil)
    }
    // Added by the branch and deleted, `HEAD`'s copy is shown removed, staging unmarked;
    // none there either is the missing notice, and only a throw leaves git unable to say.
    let headSize: Int?
    do {
      headSize = try await git.committedSize(of: repository.path, in: repository.directory)
    } catch {
      return nil
    }
    return CommittedSide(commit: nil, size: headSize, marksStaging: false)
  }

  /// The rows, those the index holds marked staged where the side marks staging.
  private static func rows(
    of lines: [DiffLine],
    staged: Data?,
    encoding: String.Encoding,
    marksStaging: Bool,
  ) -> FileTabRows {
    guard marksStaging, let staged,
      case .lines(let stagedLines) = UnifiedPatchParser.parse(staged, encoding: encoding)
    else { return FileTabRows(lines: lines, marksStaging: marksStaging) }
    return FileTabRows(
      lines: StagedChangeMarker.marking(lines, stagedIn: stagedLines),
      marksStaging: true,
    )
  }

  /// The committed text, every line removed.
  private static func deletedContent(
    path: String,
    in repository: URL,
    against side: CommittedSide,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FileTabContent {
    // Naming `HEAD` skips the staged diff, which rows marking no staging never read.
    let commit = side.marksStaging ? nil : side.commit ?? "HEAD"
    guard
      let patches = await git.patches(
        of: path,
        in: repository,
        diffAlgorithm: diffAlgorithm,
        since: commit,
      )
    else { return .missing }
    // The patch holds the committed bytes, so it is guessed as the file would be.
    let encoding = TextDecoding.decode(patches.onDisk)?.encoding ?? .utf8
    switch UnifiedPatchParser.parse(patches.onDisk, encoding: encoding) {
    case .binary:
      return .binary(bytes: side.size ?? 0)

    case .lines(let lines):
      return .text(
        rows(
          of: lines,
          staged: patches.staged,
          encoding: encoding,
          marksStaging: side.marksStaging,
        )
      )

    case .modeOnly, .unchanged:
      return .missing
    }
  }

  /// A file with no committed side and nothing staged is untracked: every
  /// line added, no git needed beyond what said so.
  private static func content(
    of data: Data,
    path: String,
    in repository: URL,
    against side: CommittedSide,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FileTabContent {
    guard let (text, encoding) = TextDecoding.decode(data) else {
      return .binary(bytes: data.count)
    }
    let marksStaging = side.marksStaging
    let patches = await git.patches(
      of: path,
      in: repository,
      diffAlgorithm: diffAlgorithm,
      since: side.commit,
    )
    let onDiskPatch = patches.map { UnifiedPatchParser.parse($0.onDisk, encoding: encoding) }
    switch onDiskPatch ?? .unchanged {
    case .binary:
      return .binary(bytes: data.count)

    case .lines(let lines):
      // Out of the index but on disk, git prints it deleted; it is the new file it is,
      // unless git ignores it, which the list shows deleted too.
      let isWhollyRemoved = !data.isEmpty && lines.allSatisfy { $0.kind == .removed }
      if isWhollyRemoved, await git.ignoredPaths([path], in: repository)?.contains(path) == false {
        return .text(
          FileTabRows(lines: plainLines(text, kind: .added), marksStaging: marksStaging)
        )
      }
      return .text(
        rows(of: lines, staged: patches?.staged, encoding: encoding, marksStaging: marksStaging)
      )

    case .modeOnly:
      return .text(
        FileTabRows(
          lines: plainLines(text, kind: .context),
          marksStaging: marksStaging,
          hasModeChange: true,
        )
      )

    case .unchanged:
      // A new file is every line added; one git ignores is shown as it is.
      var isNew = side.size == nil
      if isNew { isNew = await git.ignoredPaths([path], in: repository)?.contains(path) == false }
      return .text(
        FileTabRows(
          lines: plainLines(text, kind: isNew ? .added : .context),
          marksStaging: marksStaging,
        )
      )
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
