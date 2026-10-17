import Foundation
import MultishellGitKit

/// A worktree's paths as a tree, the costly half of `FileTree`: built again
/// only when a listing moved or a path was added or deleted, not for an edit.
struct FileTreeListing: Sendable {
  /// What a listing is built from; a status whose counts alone moved keeps it.
  struct Key: Equatable, Sendable {
    let tracked: TrackedFiles
    let untrackedPaths: [String]
    private let submodules: [String: TrackedFiles]
    private let submoduleUntrackedPaths: [String: [String]]
    let ignoredEntries: [String]
    private let ignoredFolderEntries: [String: [IgnoredFolderEntry]]
    /// A deleted file is listed by its change once the index no longer has it;
    /// a modified one is in the tracked list unless past its cap.
    fileprivate let changedPathsTrackedMayLack: Set<String>

    init(_ sources: FileTreeSources) {
      tracked = sources.tracked
      untrackedPaths = sources.status?.untrackedPaths ?? []
      submodules = sources.submodules.mapValues(\.tracked)
      submoduleUntrackedPaths = sources.submodules.mapValues { $0.status?.untrackedPaths ?? [] }
      ignoredEntries = sources.ignoredEntries
      ignoredFolderEntries = sources.ignoredFolderEntries
      let isCapped = sources.tracked.isCapped
      changedPathsTrackedMayLack = Set(
        FileTree.statusChanges(in: sources).filter { isCapped || $0.kind != .modified }.map(\.path)
      )
    }
  }

  /// What a panel draws while its first large listing is built.
  static let empty = Self(FileTreeSources(), key: Key(FileTreeSources()))

  let key: Key
  /// What building it took off the main actor, which paces the reads that move it.
  var buildCost = Duration.zero
  let roots: [FileTree.Node]
  let filePaths: [String]
  /// `filePaths` folded once, so a filter folds only its own text.
  let foldedFilePaths: [String]
  let ignoredFiles: Set<String>
  let notCheckedOutFiles: Set<String>
  let repositories: Set<String>
  /// The submodules and ignored folders read from disk, listed only open.
  let readFolders: Set<String>

  init(_ sources: FileTreeSources, key: Key) {
    self.key = key
    let tracked = sources.tracked
    var files = Set(tracked.paths)
    files.formUnion(key.untrackedPaths)
    files.formUnion(key.changedPathsTrackedMayLack)
    for (folder, submodule) in sources.submodules {
      let inside = submodule.tracked.paths + (submodule.status?.untrackedPaths ?? [])
      files.formUnion(inside.map { folder + "/" + $0 })
    }
    var notCheckedOut = tracked.notCheckedOutPaths
    for (folder, submodule) in sources.submodules {
      notCheckedOut.formUnion(submodule.tracked.notCheckedOutPaths.map { folder + "/" + $0 })
    }
    notCheckedOutFiles = notCheckedOut
    readFolders = Set(sources.submodules.keys).union(sources.ignoredFolderEntries.keys)
    repositories = tracked.submodulePaths.union(
      files.filter { $0.hasSuffix("/") }.map { String($0.dropLast()) }
    )
    let ignored = FileTree.ignoredFilesAndFolders(sources)
    let paths = files.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
    filePaths = (paths + ignored.files).sorted()
    foldedFilePaths = filePaths.map(\.foldedForMatching)
    ignoredFiles = Set(ignored.files)
    roots = FileTree.build(
      paths + ignored.files + ignored.folders,
      folders: repositories.union(ignored.folders),
      repositories: repositories,
      ignored: Set(ignored.files + ignored.folders),
    )
  }
}
