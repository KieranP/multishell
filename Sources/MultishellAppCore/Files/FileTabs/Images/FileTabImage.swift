/// A file tab's image: the file on disk and the committed copy, one buffer
/// where their bytes match; see Docs/design/files/image-tabs.md.
public struct FileTabImage: Equatable, Sendable {
  /// `nil` where the file is gone, its committed copy shown alone.
  let onDisk: ImageFileBytes?
  /// `nil` where the committed side has none, holds no image or is too large.
  let committed: ImageFileBytes?
  /// Where `committed` was read from, so a read finding it unmoved keeps it.
  let committedObjectID: String?
  /// Both copies there and their bytes differing, found off the main actor.
  let isChanged: Bool

  /// The copies drawn side by side, committed first, each labelled only
  /// where there are two.
  public var shownCopies: [ShownImageCopy] {
    switch (committed, onDisk) {
    case (let committed?, let onDisk?) where isChanged:
      [
        ShownImageCopy(image: committed, source: .committed, side: .before),
        ShownImageCopy(image: onDisk, source: .onDisk, side: .after),
      ]

    case (_, let onDisk?): [ShownImageCopy(image: onDisk, source: .onDisk, side: nil)]
    case (let committed?, nil): [ShownImageCopy(image: committed, source: .committed, side: nil)]
    case (nil, nil): []
    }
  }

  /// The last read's buffers where the bytes match, and the file's for a committed
  /// copy matching it, so comparing two readings reads no bytes. Blocking.
  static func sharingBuffers(
    onDisk read: ImageFileBytes?,
    committed: ImageFileBytes?,
    committedObjectID: String?,
    keptFrom previous: Self?,
  ) -> Self? {
    var onDisk = read
    var committed = committed
    if let kept = previous?.onDisk, kept.data == onDisk?.data { onDisk = kept }
    let isSame = committed != nil && committed?.data == onDisk?.data
    if isSame { committed = onDisk }
    guard onDisk != nil || committed != nil else { return nil }
    return Self(
      onDisk: onDisk,
      committed: committed,
      committedObjectID: committedObjectID,
      isChanged: committed != nil && onDisk != nil && !isSame,
    )
  }

  /// The copy on disk alone, which a tab whose file goes keeps showing; `nil`
  /// where it showed none.
  func lastCopyOnDisk() -> Self? {
    onDisk.map { Self(onDisk: $0, committed: nil, committedObjectID: nil, isChanged: false) }
  }
}
