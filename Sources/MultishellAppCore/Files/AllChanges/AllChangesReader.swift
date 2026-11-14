import Foundation
import MultishellCore
import MultishellGitKit

/// Reads every changed file of a worktree for the All changes tab, each as a
/// file tab reads it; see Docs/design/files/all-changes-tab.md.
enum AllChangesReader {
  /// The rows held across every file before the rest show their header
  /// alone; measured in Docs/design/files/all-changes-tab.md.
  static let rowCap = 200_000
  /// Each file is its own git run, so a few at once fill the wait on each.
  private static let concurrentReads = 4

  /// `previous` keeps each file `stale` does not name whose change and
  /// signature stand; a folder, a submodule's, is left out as Changes leaves it.
  static func read(
    _ changes: [AllChangesFileChange],
    in worktree: URL,
    git: WorktreeGit,
    diffAlgorithm: DiffAlgorithm,
    since base: DefaultBranch?,
    previous: AllChangesReading?,
    rereading stale: AllChangesStaleness,
    imageRule: ImageRule,
    rowCap: Int = rowCap,
  ) async -> (reading: AllChangesReading, filesRead: Int) {
    let listed = await runOnDispatch {
      changes.compactMap { change -> (AllChangesFileChange, FileSignature?)? in
        let url = worktree.appending(path: change.path)
        guard !isFolder(url) else { return nil }
        return (change, FileSignature.of(url))
      }
    }
    let kept = (previous?.files ?? []).keyedByPath()
    var files: [AllChangesFile] = []
    var heldRows = 0
    var filesRead = 0
    for batch in listed.chunked(into: concurrentReads) {
      guard heldRows < rowCap else {
        files += batch.map { AllChangesFile(change: $0.0, content: .pastRowCap, signature: $0.1) }
        continue
      }
      let read = await withTaskGroup(of: (Int, AllChangesFile).self) { group in
        for (index, (change, signature)) in batch.enumerated() {
          let last = kept[change.path]
          if let last, last.change == change, last.signature == signature,
            case .read = last.content, !stale.contains(change.path)
          {
            group.addTask { (index, last) }
            continue
          }
          filesRead += 1
          group.addTask {
            let reading = await FileTabReader.read(
              path: change.path,
              in: worktree,
              git: git,
              diffAlgorithm: diffAlgorithm,
              since: base,
              previous: last.flatMap(\.reading),
              imageRule: imageRule,
            )
            return (
              index, AllChangesFile(change: change, content: .read(reading), signature: signature),
            )
          }
        }
        var read: [(Int, AllChangesFile)] = []
        for await file in group { read.append(file) }
        return read.sorted { $0.0 < $1.0 }.map(\.1)
      }
      files += read
      heldRows += read.reduce(0) { $0 + ($1.rows?.lines.count ?? 0) }
    }
    return (AllChangesReading(listed: changes, files: files), filesRead)
  }

  private static func isFolder(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }
}
