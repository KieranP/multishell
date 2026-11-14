import Foundation
import MultishellCore

/// Each worktree's review comments on disk: read once per worktree as it is first
/// listed, written on each change; see Docs/design/files/review-comments.md.
extension AppModel {
  /// At launch and after each worktree list read, for a worktree not read yet; a
  /// sent comment past the sweep is dropped, the file left as read.
  func readReviewFilesOfNewWorktrees(now: Date = Date()) {
    var unreadableFiles: [UnreadableReviewFile] = []
    defer {
      if unreadableFiles.count == 1, let file = unreadableFiles.first {
        present(file)
      } else if unreadableFiles.count > 1 {
        present(UnreadableReviewFiles(files: unreadableFiles))
      }
    }
    for worktree in workspace.worktrees where !worktreesWithReviewFilesRead.contains(worktree.id) {
      worktreesWithReviewFilesRead.insert(worktree.id)
      let file = ReviewFile(worktreeID: worktree.id, in: reviewsDirectory)
      let loaded: [ReviewComment]
      do {
        loaded = try file.load()
      } catch {
        unreadableFiles.append(error)
        continue
      }
      // Known even with nothing readable in it, so the worktree's removal deletes it.
      guard !loaded.isEmpty || file.existsOnDisk else { continue }
      reviewFiles[worktree.id] = file
      let kept = loaded.filter { comment in
        !comment.outlivesItsSentFile(at: now, retention: DropCopies.retention)
      }
      setIfChanged(\.reviewComments[worktree.id], kept.isEmpty ? nil : kept)
    }
  }

  /// A project taken off the sidebar leaves its worktrees on disk, so their review
  /// files stay as written, for the project added again, rather than going with them.
  func releaseReviewFiles(of ids: [Worktree.ID]) {
    for id in ids {
      // A change not yet on disk, or whose save failed, is written before the file is let go.
      if let file = reviewFiles[id] { writeUnsavedReviewComments(of: id, to: file) }
      reviewFiles[id] = nil
      setIfChanged(\.reviewComments[id], nil)
    }
  }

  /// On the calling thread, at quit: a write still in flight would be cut off.
  func writeReviewCommentsNow() {
    for (id, file) in reviewFiles { writeUnsavedReviewComments(of: id, to: file) }
  }

  /// On the calling thread. A file no change has touched since it last landed is left as it is.
  private func writeUnsavedReviewComments(of id: Worktree.ID, to file: ReviewFile) {
    guard file.hasUnsavedChanges, !isYieldingToRunningInstance else { return }
    let comments = reviewComments(in: id)
    recordReviewSaveOutcome(Result { try file.save(comments, as: file.issueTicket()) })
  }

  /// Apart from the state file's, so one file's success cannot reopen the other's alert.
  func recordReviewSaveOutcome(_ outcome: Result<Void, any Error>) {
    recordSaveOutcome(outcome, reported: \.hasReportedReviewSaveFailure)
  }

  /// Written off the main actor at once, a comment being rarer than a
  /// keystroke; the file's ticket keeps the writes in order.
  func setReviewComments(_ comments: [ReviewComment], of worktreeID: Worktree.ID) {
    let allChanges = workspace.allChangesTab(in: worktreeID)
    let laidOutBefore = allChanges.flatMap { allChangesDocuments[$0.id]?.document.text }
    setIfChanged(\.reviewComments[worktreeID], comments.isEmpty ? nil : comments)
    // A comment holds lines open in the All changes tab, moving what its find searched.
    if let allChanges { rerunFileFind(in: allChanges.id, laidOutBefore: laidOutBefore) }
    guard !isYieldingToRunningInstance else { return }
    let file = reviewFile(of: worktreeID)
    let ticket = file.issueTicket()
    Task { @MainActor [weak self] in
      let outcome = await runOnDispatch { Result { try file.save(comments, as: ticket) } }
      self?.recordReviewSaveOutcome(outcome)
    }
  }

  private func reviewFile(of worktreeID: Worktree.ID) -> ReviewFile {
    if let file = reviewFiles[worktreeID] { return file }
    let file = ReviewFile(worktreeID: worktreeID, in: reviewsDirectory)
    reviewFiles[worktreeID] = file
    return file
  }
}
