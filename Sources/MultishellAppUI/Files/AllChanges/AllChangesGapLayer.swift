import AppKit
import MultishellAppCore
import SwiftUI

/// The All changes tab's headers, folds and notices, each in the gap under the
/// row before it, below any review cards there, and a box around each file,
/// laid across the gutter and text or both split columns, on the canvas by the
/// document's offsets. Only those near the clip are hosted, each host being a
/// surface of its own; see Docs/design/files/all-changes-tab.md.
@MainActor
final class AllChangesGapLayer {
  private static let boxCornerRadius: CGFloat = 6

  private var items: [AllChangesGapItem] = []
  private var heights: [AllChangesGapItem: CGFloat] = [:]
  private var content: (AllChangesGapItem) -> AnyView = { _ in AnyView(EmptyView()) }
  private weak var parent: NSView?
  /// What each shown item's host was last given, so a scroll rebuilds none.
  private var hosts: [AllChangesGapItem: NSHostingController<AnyView>] = [:]
  private var hostedGeneration: [AllChangesGapItem: Int] = [:]
  private var generation = 0
  /// Hosts let go of as their items left the clip, given to the next to enter.
  private var spareHosts: [NSHostingController<AnyView>] = []
  /// Every item's place in the document at the last layout, hosted or not.
  private var frames: [AllChangesGapItem: NSRect] = [:]
  /// The cards' gap under each row, which the items stack below.
  private var cardGaps: [Int: CGFloat] = [:]
  /// Each file's box near the clip by its section, and boxes let go of; a
  /// border-only layer has no backing store, so a tall one costs nothing.
  private var boxes: [Int: CALayer] = [:]
  private var spareBoxes: [CALayer] = []
  private var boxBorder: CGColor?

  /// Keeps what each item shows and returns the gap each row needs; hosts come
  /// with the next layout.
  func show(
    _ items: [AllChangesGapItem],
    height: (AllChangesGapItem) -> CGFloat,
    content: @escaping (AllChangesGapItem) -> AnyView,
    boxBorder: CGColor,
    in parent: NSView,
  ) -> [Int: CGFloat] {
    self.items = items
    self.boxBorder = boxBorder
    for box in boxes.values { box.borderColor = boxBorder }
    self.content = content
    self.parent = parent
    generation += 1
    heights = Dictionary(items.map { ($0, height($0)) }, uniquingKeysWith: { first, _ in first })
    for item in hosts.keys where heights[item] == nil { retire(item) }
    frames = frames.filter { heights[$0.key] != nil }
    return items.reduce(into: [:]) { gaps, item in
      gaps[item.afterRow, default: 0] += heights[item] ?? 0
    }
  }

  func noteCardGaps(_ gaps: [Int: CGFloat]) {
    cardGaps = gaps
  }

  /// Across the parent, stacked down each gap in order; `shown` is the
  /// document's span on screen, past which nothing is hosted, and `end` where
  /// the last file's rows end.
  func layOut(
    in geometry: DiffRowGeometry,
    x: CGFloat,
    width: CGFloat,
    shown: ClosedRange<CGFloat>,
    end: CGFloat,
  ) {
    var nextTop: [Int: CGFloat] = [:]
    var near: [AllChangesGapItem] = []
    // Each host is a layer-backed surface of its own, so only a header's height
    // past either edge is hosted ahead of a scroll.
    let reach = CGFloat(UIMetrics.allChangesHeaderBarHeight)
    let hosted = (shown.lowerBound - reach)...(shown.upperBound + reach)
    for item in items {
      let height = heights[item] ?? 0
      let row = item.afterRow
      let top = nextTop[row] ?? geometry.gapTop(afterRow: row) + (cardGaps[row] ?? 0)
      let frame = NSRect(x: x, y: top, width: width, height: height)
      frames[item] = frame
      nextTop[row] = top + height
      // A file shown whole has a view of its own, which `AllChangesWholeFileLayer` hosts.
      if item.kind != .wholeFile, frame.maxY >= hosted.lowerBound, frame.minY <= hosted.upperBound {
        near.append(item)
      }
    }
    let kept = Set(near)
    for item in hosts.keys where !kept.contains(item) { retire(item) }
    for item in near {
      let host = hosts[item] ?? takeHost()
      hosts[item] = host
      if hostedGeneration[item] != generation {
        host.rootView = content(item)
        hostedGeneration[item] = generation
      }
      if let frame = frames[item], host.view.frame != frame { host.view.frame = frame }
    }
    layOutBoxes(x: x, width: width, hosted: hosted, end: end)
  }

  /// From under each header's gap to the next header, or the last file's end.
  private func layOutBoxes(
    x: CGFloat,
    width: CGFloat,
    hosted: ClosedRange<CGFloat>,
    end: CGFloat,
  ) {
    let headers = items.filter { $0.kind == .header }
    var near: [Int: NSRect] = [:]
    for (index, header) in headers.enumerated() {
      guard let frame = frames[header] else { continue }
      let top = frame.minY + UIMetrics.allChangesFileGap
      let bottom =
        headers.indices.contains(index + 1) ? frames[headers[index + 1]]?.minY ?? end : end
      guard bottom >= hosted.lowerBound, top <= hosted.upperBound else { continue }
      near[header.section] = NSRect(x: x, y: top, width: width, height: max(0, bottom - top))
    }
    for (section, box) in boxes where near[section] == nil {
      box.isHidden = true
      spareBoxes.append(box)
      boxes[section] = nil
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for (section, frame) in near {
      let box = boxes[section] ?? takeBox()
      boxes[section] = box
      box.frame = frame
    }
    CATransaction.commit()
  }

  private func takeBox() -> CALayer {
    if let spare = spareBoxes.popLast() {
      spare.isHidden = false
      return spare
    }
    let box = CALayer()
    box.borderWidth = 1
    box.cornerRadius = Self.boxCornerRadius
    box.borderColor = boxBorder
    // Over the text and the hosted views, the border alone drawn.
    box.zPosition = 2
    parent?.wantsLayer = true
    parent?.layer?.addSublayer(box)
    return box
  }

  /// Where an item sits in the document once laid out, hosted or not; `nil` before.
  func frame(of item: AllChangesGapItem) -> NSRect? {
    frames[item]
  }

  /// Where a file's header bar starts in the document, under its file gap,
  /// once laid out; `nil` past the last file.
  func headerBarTop(ofSection index: Int, in document: AllChangesDocument) -> Double? {
    guard document.sections.indices.contains(index),
      let header = frames[document.headerItem(ofSection: index)]
    else { return nil }
    return Double(header.minY) + UIMetrics.allChangesFileGap
  }

  private func retire(_ item: AllChangesGapItem) {
    guard let host = hosts.removeValue(forKey: item) else { return }
    hostedGeneration[item] = nil
    host.view.isHidden = true
    spareHosts.append(host)
  }

  private func takeHost() -> NSHostingController<AnyView> {
    if let spare = spareHosts.popLast() {
      spare.view.isHidden = false
      return spare
    }
    let host = NSHostingController(rootView: AnyView(EmptyView()))
    host.sizingOptions = []
    host.view.wantsLayer = true
    // TextKit 2 adds its fragments' views as it lays out; these stay over them.
    host.view.layer?.zPosition = 1
    parent?.addSubview(host.view)
    return host
  }
}
