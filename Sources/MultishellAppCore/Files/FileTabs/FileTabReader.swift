import Foundation
import MultishellCore
import MultishellGitKit

/// Reads one file tab's file and its changes against `HEAD`, or where its
/// branch left `base`; see Docs/design/files/modified-and-branch.md.
enum FileTabReader {
  /// The spikes: git diffs 1 MiB in under 40 ms, but the forced TextKit 2
  /// view takes up to 186 MB laid out at that size.
  static let sizeLimit = 1 << 20

  /// `previous` is the last read, which a file deleted under an open tab keeps
  /// showing; `imageRule` says whether the name is an image's.
  static func read(
    path pathInWorktree: String,
    in worktree: URL,
    git: WorktreeGit,
    diffAlgorithm: DiffAlgorithm,
    since base: DefaultBranch?,
    previous: FileTabReading?,
    imageRule: ImageRule,
  ) async -> FileTabReading {
    let url = worktree.appending(path: pathInWorktree)
    let (onDisk, repository, isImage, image) = await runOnDispatch {
      let isImage = imageRule.opensAsImage(pathInWorktree)
      let onDisk = FileOnDisk.read(
        url,
        sizeLimit: isImage ? FileTabImageReader.sizeLimit : sizeLimit,
      )
      return (
        onDisk,
        RepositoryLocation.innermost(holding: pathInWorktree, in: worktree),
        isImage,
        isImage ? onDisk.bytes.flatMap { FileTabImageReader.bytes($0, imageRule) } : nil,
      )
    }
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
    // An image's name past the text cap with bytes no decoder reads is text's to judge.
    if let data, image == nil, data.count > sizeLimit {
      return FileTabReading(content: .tooLarge(bytes: data.count), isFileGone: false)
    }
    let readsAsImage = isImage && (image != nil || isGone)
    let resolved = await committedSide(
      of: repository,
      in: worktree,
      since: base,
      isGone: isGone,
      git: git,
    )
    if readsAsImage,
      let content = await FileTabImageReader.content(
        onDisk: image,
        of: repository,
        against: resolved,
        git: git,
        previous: previous.flatMap(\.image),
        imageRule,
      )
    {
      return FileTabReading(content: content, isFileGone: isGone)
    }
    guard let side = resolved else {
      // What it counts from is unknown: the last rows or image, else none rather than a guess.
      if let previous, previous.content.showsTheFile, previous.isFileGone == isGone {
        return previous
      }
      return FileTabReading(content: .unreadable, isFileGone: isGone)
    }
    return await textReading(of: data, in: repository, against: side, git: git, diffAlgorithm)
  }

  /// Text, or a notice where it is none or too large, against a side resolved.
  private static func textReading(
    of data: Data?,
    in repository: RepositoryLocation,
    against side: CommittedSide,
    git: WorktreeGit,
    _ diffAlgorithm: DiffAlgorithm,
  ) async -> FileTabReading {
    // A file in a submodule is diffed against the submodule's own `HEAD`.
    let path = repository.path
    let isGone = data == nil
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
    // A tab that showed the file keeps its last text or copy; one showing the
    // committed side reads it again, a commit being able to move it.
    guard let previous else { return nil }
    if previous.isFileGone { return previous.content.isLastOnDisk ? previous : nil }
    return previous.content.lastOnDisk().map { FileTabReading(content: $0, isFileGone: true) }
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
          FileTabRows(
            lines: PlainDiffLines.of(text, kind: .added),
            marksStaging: marksStaging,
          )
        )
      }
      return .text(
        rows(of: lines, staged: patches?.staged, encoding: encoding, marksStaging: marksStaging)
      )

    case .modeOnly:
      return .text(
        FileTabRows(
          lines: PlainDiffLines.of(text, kind: .context),
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
          lines: PlainDiffLines.of(text, kind: isNew ? .added : .context),
          marksStaging: marksStaging,
        )
      )
    }
  }
}
