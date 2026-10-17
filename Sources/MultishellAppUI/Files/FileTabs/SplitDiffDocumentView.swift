import AppKit
import MultishellAppCore
import MultishellCore

/// `HEAD` on the left, the file on disk on the right, locked by scroll offset,
/// the same row on both sides under forced geometry; see files.md.
@MainActor
final class SplitDiffDocumentView: NSView {
  let committed: DiffDocumentView
  let onDisk: DiffDocumentView
  private let divider = NSView()
  private var isFollowing = false
  /// Each side's last origin, so only a sideways scroll is passed on sideways.
  private var lastOrigins: [ObjectIdentifier: NSPoint] = [:]

  private var split: SplitDiff?
  /// By the right side's scroll, which the left follows by the lock, anchored
  /// by the split as a whole: `HEAD`'s line where the left shows a removal.
  var onScrolledTo: ((FileTabScroll) -> Void)?

  init(geometry: DiffRowGeometry) {
    committed = DiffDocumentView(geometry: geometry)
    onDisk = DiffDocumentView(geometry: geometry)
    super.init(frame: .zero)
    clipsToBounds = true
    committed.numbering = .committed
    committed.textView.copiesAsDiff = false
    onDisk.textView.copiesAsDiff = false
    divider.wantsLayer = true
    for view in [committed, divider, onDisk] { addSubview(view) }
    committed.onScroll = { [weak self] origin in
      self?.follow(origin, of: self?.committed, with: self?.onDisk)
    }
    onDisk.onScroll = { [weak self] origin in
      self?.follow(origin, of: self?.onDisk, with: self?.committed)
    }
    onDisk.onScrolledTo = { [weak self] onDiskScroll in
      guard let self else { return }
      onScrolledTo?(split?.scroll(atRow: onDisk.topRow, x: onDiskScroll.x) ?? onDiskScroll)
    }
  }

  required init?(coder: NSCoder) { nil }

  /// On the side that has the line, the lock bringing the other along.
  func restore(_ scroll: FileTabScroll) {
    let (restoring, following) = scroll.isHEADsLine ? (committed, onDisk) : (onDisk, committed)
    restoring.restore(scroll)
    following.awaitTheLock()
  }

  func show(_ split: SplitDiff, theme: Theme) {
    self.split = split
    divider.layer?.backgroundColor = theme.splitDividerColor.cgColor
    committed.show(split.committed, theme: theme)
    onDisk.show(split.onDisk, theme: theme)
  }

  override func layout() {
    super.layout()
    let half = (bounds.width - 1) / 2
    committed.frame = NSRect(x: 0, y: 0, width: half, height: bounds.height)
    divider.frame = NSRect(x: half, y: 0, width: 1, height: bounds.height)
    onDisk.frame = NSRect(x: half + 1, y: 0, width: bounds.width - half - 1, height: bounds.height)
  }

  /// Rows by the same offset; sideways only when this side moved sideways, as
  /// the narrower side's clamp would otherwise pull the wider one back.
  private func follow(_ origin: NSPoint, of side: DiffDocumentView?, with other: DiffDocumentView?)
  {
    guard let side, let other else { return }
    let previous = lastOrigins.updateValue(origin, forKey: ObjectIdentifier(side))
    guard !isFollowing else { return }
    isFollowing = true
    let movedSideways = previous.map { $0.x != origin.x } ?? true
    other.scroll(to: NSPoint(x: movedSideways ? origin.x : other.scrollOrigin.x, y: origin.y))
    lastOrigins[ObjectIdentifier(other)] = other.scrollOrigin
    isFollowing = false
  }
}
