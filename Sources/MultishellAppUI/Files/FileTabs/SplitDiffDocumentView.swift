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
  /// From the side holding the keyboard, as a step counts.
  var onStepsCounted: ((ChangeSteps) -> Void)?
  /// The change either side boxed or let go of, as Unified holds it, for the
  /// model to keep.
  var onSteppedChangeAnchorChanged: ((ChangeAnchor?) -> Void)?
  private var firstResponderWatch: NSKeyValueObservation?

  /// The right where neither side has the keyboard, as find counts there.
  private var keyboardSide: DiffDocumentView {
    window?.firstResponder === committed.textView ? committed : onDisk
  }

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
    for (side, other) in [(committed, onDisk), (onDisk, committed)] {
      side.onSteppedRowsChanged = { [weak self, weak other] rows in
        other?.mirrorSteppedChange(rows)
        self?.onSteppedChangeAnchorChanged?(rows.flatMap { self?.split?.anchor(ofChangeAt: $0) })
      }
      // The other side moves only by the lock; a keyboard crossing over is
      // counted by the first responder's watch.
      side.onStepOriginMoved = { [weak self, weak side] in
        guard let self, let side, side === keyboardSide else { return }
        countKeyboardSide()
      }
    }
  }

  required init?(coder: NSCoder) { nil }

  /// On the side that has the line, the lock bringing the other along.
  func restore(_ scroll: FileTabScroll) {
    let (restoring, following) = scroll.isHEADsLine ? (committed, onDisk) : (onDisk, committed)
    restoring.restore(scroll)
    following.awaitTheLock()
  }

  /// Both sides' changes sit on the same rows, so either side's step is the
  /// split's, and the lock and the box's mirror bring the other along.
  func step(toChange direction: CycleDirection) {
    keyboardSide.step(toChange: direction)
  }

  /// Where a dropped view of this tab, Unified or Split, boxed a change; the
  /// right side's to take, as it holds a box the split carries.
  func restoreSteppedChangeAnchor(_ anchor: ChangeAnchor) {
    onDisk.restoreSteppedChangeAnchor(anchor)
  }

  /// The keyboard can cross sides with no scroll or selection to count on;
  /// a move between other views of the window is not counted.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    firstResponderWatch = window?.observe(\.firstResponder, options: [.old, .new]) {
      [weak self] _, change in
      let movedBetween = [change.oldValue, change.newValue].compactMap { $0 ?? nil }
        .map(ObjectIdentifier.init)
      MainActor.assumeIsolated {
        guard let self else { return }
        let sides = [self.committed.textView, self.onDisk.textView].map(ObjectIdentifier.init)
        if movedBetween.contains(where: sides.contains) { self.countKeyboardSide() }
      }
    }
  }

  private func countKeyboardSide() {
    onStepsCounted?(keyboardSide.changeSteps)
  }

  /// The box is carried by the split as a whole, once both sides are shown, on
  /// the side holding the keyboard, whose mirror then has its new rows to box.
  func show(_ split: SplitDiff, theme: Theme) {
    let steppedChangeAnchor = onDisk.takeSteppedChangeAnchorToCarry(boxedIn: self.split)
    // Unboxed first, so neither side carries the box by its own half of the change.
    committed.mirrorSteppedChange(nil)
    onDisk.mirrorSteppedChange(nil)
    self.split = split
    divider.layer?.backgroundColor = theme.splitDividerColor.cgColor
    committed.show(split.committed, theme: theme)
    onDisk.show(split.onDisk, theme: theme)
    keyboardSide.carrySteppedChange(steppedChangeAnchor, into: split)
    // Each side counted as it was shown, before the box was carried.
    countKeyboardSide()
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
