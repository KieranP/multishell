import Foundation
import MultishellCore

/// What a checkout's git directory says is stopped partway, read from the files
/// git leaves there: no git run, so the status poll pays a few stats.
enum UnfinishedOperationFiles {
  static func unfinishedUpdate(inCheckout checkout: URL) -> UpdateMethod? {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout) else { return nil }
    if exists("rebase-merge", in: gitDirectory)
      || (exists("rebase-apply", in: gitDirectory) && !isApplyingPatches(gitDirectory))
    {
      return .rebase
    }
    return exists("MERGE_HEAD", in: gitDirectory) ? .merge : nil
  }

  /// What tells one stop from the next of its kind: the commit a rebase began from
  /// and the one it moves onto, or the commit a merge takes in. `nil` with none.
  static func unfinishedUpdateMark(inCheckout checkout: URL) -> String? {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout),
      let method = unfinishedUpdate(inCheckout: checkout)
    else { return nil }
    // A `rebase -r` writes MERGE_HEAD at each merge step, so a rebase's mark leaves it out.
    let markFiles =
      switch method {
      case .merge: ["MERGE_HEAD"]
      case .rebase: ["rebase-merge", "rebase-apply"].flatMap { ["\($0)/orig-head", "\($0)/onto"] }
      }
    let marks = markFiles.compactMap { name in
      try? String(contentsOf: gitDirectory.appendingPathComponent(name), encoding: .utf8)
    }
    return marks.isEmpty ? nil : marks.joined()
  }

  /// Whether the stopped rebase began from `head` onto `tip`, which tells an
  /// update's own stop from one another began.
  static func isRebase(from head: String, onto tip: String, inCheckout checkout: URL) -> Bool {
    ["rebase-merge", "rebase-apply"].contains { state in
      firstLine(of: "\(state)/orig-head", inCheckout: checkout) == head
        && firstLine(of: "\(state)/onto", inCheckout: checkout) == tip
    }
  }

  /// The first line of a file in the checkout's git directory, `nil` for none.
  static func firstLine(of name: String, inCheckout checkout: URL) -> String? {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout) else { return nil }
    let file = gitDirectory.appendingPathComponent(name)
    return (try? String(contentsOf: file, encoding: .utf8))?.gitLines.first
  }

  /// Whether git keeps the checkout's refs in reftable, where pseudo-refs such as
  /// ORIG_HEAD are no files; MERGE_HEAD and the rebase directories still are.
  static func keepsRefsInReftable(inCheckout checkout: URL) -> Bool {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout) else { return false }
    return exists("reftable", in: gitDirectory)
  }

  /// The branch a stopped rebase will put back, which git lists the worktree
  /// without until it ends, from the `head-name` it keeps.
  static func branchBeingRebased(inCheckout checkout: URL) -> String? {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout) else { return nil }
    for state in ["rebase-merge", "rebase-apply"] {
      let file = gitDirectory.appendingPathComponent(state).appendingPathComponent("head-name")
      guard let text = try? String(contentsOf: file, encoding: .utf8),
        let ref = text.gitLines.first
      else { continue }
      // A rebase begun detached writes the words "detached HEAD" there.
      return ref.hasPrefix(RefName.localPrefix) ? RefName.shortLocal(ref) : nil
    }
    return nil
  }

  /// A pick list or `git am` stopped partway; the list outlives its CHERRY_PICK_HEAD
  /// once a stop is committed by hand. The pseudo-refs are `WorktreeGit`'s to read.
  static func isPickingFromAList(inCheckout checkout: URL) -> Bool {
    guard let gitDirectory = gitDirectory(ofCheckout: checkout) else { return false }
    return exists("sequencer/todo", in: gitDirectory) || isApplyingPatches(gitDirectory)
  }

  /// git's own mark of a `git am` in the `rebase-apply` it shares with a rebase.
  private static func isApplyingPatches(_ gitDirectory: URL) -> Bool {
    exists("rebase-apply/applying", in: gitDirectory)
  }

  private static func exists(_ name: String, in gitDirectory: URL) -> Bool {
    FileManager.default.fileExists(atPath: gitDirectory.appendingPathComponent(name).path)
  }

  /// `.git` itself in a main checkout, the record its file names in a linked one.
  private static func gitDirectory(ofCheckout checkout: URL) -> URL? {
    let dotGit = checkout.appendingPathComponent(".git")
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDirectory) else {
      return nil
    }
    return isDirectory.boolValue ? dotGit : WorktreeGit.recordDirectoryFromGitFile(in: checkout)
  }
}
