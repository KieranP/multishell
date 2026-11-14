import MultishellCore

/// Which files a read of the All changes tab reads, and what the rest land as.
struct AllChangesReadPlan {
  /// The last read under the same base, `nil` under another.
  let kept: AllChangesReading?
  let stale: AllChangesStaleness
  /// The files near the screen; `nil` reads every file.
  let near: Set<String>?
  let imageRule: ImageRule

  /// What a file lands as without a read; `nil` where it is read now. An image
  /// shows its notice alone, its bytes, up to 32 MiB a side, left unread.
  func landsWithoutRead(
    _ change: AllChangesFileChange,
    _ signature: FileSignature?,
  )
    -> AllChangesFile?
  {
    guard !imageRule.opensAsImage(change.path) else {
      return AllChangesFile(change: change, content: .image, signature: signature)
    }
    if let unchanged = unchangedSinceLast(change, signature) { return unchanged }
    guard let near, !near.contains(change.path) else { return nil }
    guard let last = kept?.file(at: change.path), case .read = last.content else {
      return AllChangesFile(change: change, content: .unread, signature: signature)
    }
    // Away from the screen: its last rows, kept stale.
    return AllChangesFile(
      change: change,
      content: last.content,
      signature: last.signature,
      isStale: true,
    )
  }

  /// The last read of a file whose change and signature stand and that no event
  /// named since.
  private func unchangedSinceLast(
    _ change: AllChangesFileChange,
    _ signature: FileSignature?,
  )
    -> AllChangesFile?
  {
    guard let last = kept?.file(at: change.path), last.change == change,
      last.signature == signature,
      case .read = last.content, !last.isStale, !stale.contains(change.path)
    else { return nil }
    return last
  }
}
