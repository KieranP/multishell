import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// One file's folds and notices, each in the gap under the row before it and below
/// any cards there, across gutter and text or both split columns.
@MainActor
final class AllChangesGapLayer {
  private var items: [AllChangesGapItem] = []
  private var heights: [AllChangesGapItem: CGFloat] = [:]
  private var content: (AllChangesGapItem, CGFloat) -> AnyView = { _, _ in AnyView(EmptyView()) }
  /// Where the file's code starts, which a fold's label lines up with.
  private var codeX: CGFloat = 0
  private weak var parent: NSView?
  /// What each item's host was last given, so a layout rebuilds none.
  private var hosts: [AllChangesGapItem: NSHostingController<AnyView>] = [:]
  private var hostedGeneration: [AllChangesGapItem: Int] = [:]
  private var generation = 0
  private var contentKey: AnyHashable?
  /// Hosts let go of as their items went, given to the next shown.
  private var spareHosts: [NSHostingController<AnyView>] = []
  /// The cards' gap under each row, which the items stack below.
  private var cardGaps: [Int: CGFloat] = [:]

  /// Keeps what each item shows and returns the gap each row needs; hosts come
  /// with the next layout, built again only where the items or `contentKey` moved.
  func show(
    _ items: [AllChangesGapItem],
    contentKey: AnyHashable,
    height: (AllChangesGapItem) -> CGFloat,
    content: @escaping (AllChangesGapItem, CGFloat) -> AnyView,
    in parent: NSView,
  ) -> [Int: CGFloat] {
    if items != self.items || contentKey != self.contentKey { generation += 1 }
    self.items = items
    self.contentKey = contentKey
    self.content = content
    self.parent = parent
    heights = Dictionary(keepingFirst: items.map { ($0, height($0)) })
    for item in hosts.keys where heights[item] == nil { retire(item) }
    return items.reduce(into: [:]) { gaps, item in
      gaps[item.afterRow, default: 0] += heights[item] ?? 0
    }
  }

  /// Its view kept for another file, whose items are built afresh.
  func forgetContent() {
    contentKey = nil
  }

  func noteCardGaps(_ gaps: [Int: CGFloat]) {
    cardGaps = gaps
  }

  /// Across the parent, stacked down each gap in order; `codeX` where the
  /// file's code starts, a gutter widening with its line numbers' digits.
  func layOut(in geometry: DiffRowGeometry, width: CGFloat, codeX: CGFloat) {
    if codeX != self.codeX {
      self.codeX = codeX
      generation += 1
    }
    var nextTop: [Int: CGFloat] = [:]
    for item in items {
      let height = heights[item] ?? 0
      let row = item.afterRow
      let top = nextTop[row] ?? geometry.gapTop(afterRow: row) + (cardGaps[row] ?? 0)
      nextTop[row] = top + height
      let host = hosts[item] ?? takeHost()
      hosts[item] = host
      if hostedGeneration[item] != generation {
        host.rootView = content(item, codeX)
        hostedGeneration[item] = generation
      }
      let frame = NSRect(x: 0, y: top, width: width, height: height)
      if host.view.frame != frame { host.view.frame = frame }
    }
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
    return .overTextFragments(in: parent)
  }
}
