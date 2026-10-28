import MultishellGitKit

/// One row of the Files panel, a file or a folder, as drawn.
public struct FileTreeRow: Identifiable, Hashable, Sendable {
  /// How strongly the name is drawn.
  public enum Emphasis: Sendable {
    /// Ignored, or not to be opened.
    case faint
    /// An unchanged file.
    case quiet
    /// A change, or a folder.
    case strong
  }

  /// Relative to the worktree; a folder chain merged in the Changes list is its last.
  public let path: String
  /// The file's or folder's name, `Tests/AppCoreTests/Detail` for a merged
  /// chain of single-child folders.
  public let name: String
  /// Where a filtered file sits, shown beside its name; `nil` in the tree.
  public let parentFolder: String?
  public let depth: Int
  public let isFolder: Bool
  public let isExpanded: Bool
  let holdsChange: Bool
  /// What happened to the file, `nil` for one unchanged.
  let changeKind: StatusChange.Kind?
  /// Its `+N −M`, `nil` where it has no lines counted.
  public let lineCounts: FileLineCounts?
  /// A submodule or a nested repository: a folder whose files are another
  /// repository's.
  public let isRepository: Bool
  /// git ignores it: drawn greyed, and opened as any other.
  let isIgnored: Bool
  /// `false` for a path a sparse checkout leaves off disk, or one not valid
  /// UTF-8, which git cannot be asked about again: greyed, and not opened.
  let isOpenable: Bool

  public var id: String { path }

  public var emphasis: Emphasis {
    if isIgnored || !isOpenable { return .faint }
    return changeKind == nil && !isFolder ? .quiet : .strong
  }

  /// A folder holding a change shows a dot while it is shut.
  public var showsChangeDot: Bool { isFolder && holdsChange && !isExpanded }
}
