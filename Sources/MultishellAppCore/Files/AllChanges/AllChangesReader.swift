import Foundation
import MultishellCore
import MultishellGitKit

/// Reads every changed file of a worktree for the All changes tab, each as a
/// file tab reads it; see Docs/design/files/all-changes-tab.md.
enum AllChangesReader {
  /// The rows held across every file before the rest show their header
  /// alone; measured in Docs/design/files/all-changes-tab.md.
  static let rowCap = 200_000
  /// One file reads alone in fewer git runs than the batch's: 4 against 6, measured.
  private static let fewestFilesBatched = 2

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
    near: Set<String>? = nil,
    rowCap: Int = rowCap,
  ) async -> (reading: AllChangesReading, filesRead: Int) {
    // Rows diffed against another base are kept for no file, near or not.
    let kept = previous?.baseName == base?.shortName ? previous : nil
    let plan = AllChangesReadPlan(kept: kept, stale: stale, near: near, imageRule: imageRule)
    let listed = await files(of: changes, in: worktree)
    let landingsWithoutRead = listed.map(plan.landsWithoutRead)
    let toRead = zip(listed, landingsWithoutRead).filter { $1 == nil }.map(\.0)
    let bases = await bases(
      of: toRead,
      in: worktree,
      since: base,
      diffAlgorithm: diffAlgorithm,
      imageRule: imageRule,
      git: git,
    )
    var slots = AllChangesReadSlots(count: listed.count, rowCap: rowCap)
    var filesRead = 0
    await withTaskGroup(of: (Int, AllChangesFile).self) { group in
      var next = 0
      var inFlight = 0
      while true {
        // A steady few in flight: a batch waited on its slowest file.
        while inFlight < WorktreeGit.runsAtOnce, next < listed.count, !slots.reachesRowCap {
          let index = next
          next += 1
          let (change, signature) = listed[index]
          if let file = landingsWithoutRead[index] {
            slots.land(file, at: index)
            continue
          }
          let last = kept?.file(at: change.path)?.reading
          filesRead += 1
          inFlight += 1
          group.addTask {
            let reading = await FileTabReader.read(
              path: change.path,
              in: worktree,
              git: git,
              diffAlgorithm: diffAlgorithm,
              since: base,
              previous: last,
              imageRule: imageRule,
              bases: bases,
            )
            return (
              index, AllChangesFile(change: change, content: .read(reading), signature: signature),
            )
          }
        }
        guard inFlight > 0 else {
          if next < listed.count, !slots.isCapped { continue }
          break
        }
        guard let (index, file) = await group.next() else { break }
        inFlight -= 1
        slots.land(file, at: index)
      }
    }
    let files = slots.files(of: listed)
    return (
      AllChangesReading(listed: changes, files: files, baseName: base?.shortName), filesRead,
    )
  }

  /// What the files read count from, asked of git once; `nil` for one file, which
  /// reads alone in fewer runs.
  private static func bases(
    of toRead: [(AllChangesFileChange, FileSignature?)],
    in worktree: URL,
    since base: DefaultBranch?,
    diffAlgorithm: DiffAlgorithm,
    imageRule: ImageRule,
    git: WorktreeGit,
  ) async -> WorktreeDiffBases? {
    guard toRead.count >= fewestFilesBatched else { return nil }
    return await WorktreeDiffBases.resolve(
      in: worktree,
      since: base,
      paths: toRead.map(\.0.path),
      diffable: diffable(toRead, imageRule),
      diffAlgorithm: diffAlgorithm,
      git: git,
    )
  }

  /// Each change's file and its signature, a folder left out.
  private static func files(
    of changes: [AllChangesFileChange],
    in worktree: URL,
  ) async -> [(AllChangesFileChange, FileSignature?)] {
    await runOnDispatch {
      changes.compactMap { change -> (AllChangesFileChange, FileSignature?)? in
        let signature = FileSignature.of(worktree.appending(path: change.path))
        guard signature?.isFolder != true else { return nil }
        return (change, signature)
      }
    }
  }

  /// The files worth diffing up front: text under the cap, by name and size on disk.
  private static func diffable(
    _ files: [(AllChangesFileChange, FileSignature?)],
    _ imageRule: ImageRule,
  ) -> Set<String> {
    Set(
      files.filter { change, signature in
        !imageRule.opensAsImage(change.path) && (signature?.size ?? 0) <= FileTabReader.sizeLimit
      }
      .map(\.0.path)
    )
  }
}
