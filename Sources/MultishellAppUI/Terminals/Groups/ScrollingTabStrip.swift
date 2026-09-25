import MultishellAppCore
import MultishellCore
import SwiftUI

/// A strip whose tabs have shrunk as far as they go and still do not fit: a
/// scroller with an arrow at each end that has tabs past it.
struct ScrollingTabStrip<Tabs: View>: View {
  let model: AppModel
  let theme: Theme
  /// How wide each tab is drawn, and the floor it stopped at; see
  /// `TabStripLayout`.
  let layout: TabStripLayout
  /// The room the strip has, the buttons at its end already taken off.
  let available: Double
  /// In strip order, for the arrows to scroll by one and for the count.
  let tabIDs: [TerminalTab.ID]
  /// The tab showing, brought into view as it changes.
  let activeID: TerminalTab.ID?
  @ViewBuilder let tabs: () -> Tabs

  /// How far it has been scrolled, deciding which end carries an arrow and
  /// where it jumps to; see `TabStripLayout.Edges`.
  @State private var scrollOffset = 0.0
  /// The scroller a wheel's turns are handed to, named from inside it and
  /// caught from outside it; see `ScrollerReference`.
  @State private var scrollerReference = ScrollerReference()

  /// With no gutters the trackpad still scrolls the strip.
  private var gutter: Double { model.metrics.tabArrowGutter(forRoom: available) }

  /// Both gutters keep their room whether an arrow is drawn or not, so this,
  /// which decides that, cannot change what it is measured from.
  private var viewport: Double { available - 2 * gutter }

  var body: some View {
    let edges = TabStripLayout.Edges(
      offset: scrollOffset,
      viewport: viewport,
      content: Double(tabIDs.count) * layout.tabWidth)
    ScrollViewReader { scroller in
      HStack(spacing: 0) {
        arrow(.before, shown: edges.leading, scroller: scroller)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 0) { tabs() }
            .frame(height: model.metrics.tabHeight)
            .marksScroller(scrollerReference)
        }
        // From the content's leading edge: the offset alone rests at minus
        // any leading inset.
        .onScrollGeometryChange(for: Double.self) { geometry in
          Double(geometry.contentOffset.x + geometry.contentInsets.leading)
        } action: { _, offset in
          scrollOffset = offset
        }
        arrow(.after, shown: edges.trailing, scroller: scroller)
      }
      .wheelScrollsSideways(scrollerReference)
      // Unwrapped, both: `scrollTo` takes anything hashable, so a
      // `TerminalTab.ID?` compiles and matches nothing.
      .onAppear {
        if let activeID { scroller.scrollTo(activeID, anchor: .center) }
      }
      .onChange(of: activeID) { _, id in
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.16)) { scroller.scrollTo(id, anchor: .center) }
      }
    }
  }

  /// One end's arrow, drawn only where there are tabs past it. Its own
  /// gutter, an arrow over the tabs otherwise taking their clicks.
  @ViewBuilder
  private func arrow(
    _ placement: TerminalTab.Placement, shown: Bool, scroller: ScrollViewProxy
  ) -> some View {
    let leading = placement == .before
    if shown, gutter > 0 {
      Button {
        step(placement, scroller: scroller)
      } label: {
        Image(systemName: leading ? "chevron.compact.left" : "chevron.compact.right")
          .font(.system(size: model.metrics.body, weight: .semibold))
          .foregroundStyle(theme.textSecondary)
          .frame(width: gutter, height: model.metrics.tabHeight)
          .background(theme.chromeColor)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help(leading ? t("tab.scroll-left") : t("tab.scroll-right"))
      .accessibilityLabel(leading ? t("tab.more-left") : t("tab.more-right"))
    } else {
      // The room is kept, so the tabs stay put as an end runs out.
      Color.clear.frame(width: gutter)
    }
  }

  private func step(_ placement: TerminalTab.Placement, scroller: ScrollViewProxy) {
    guard
      let index = layout.stepTarget(
        towards: placement, offset: scrollOffset, viewport: viewport, count: tabIDs.count),
      tabIDs.indices.contains(index)
    else { return }
    withAnimation(.easeOut(duration: 0.16)) {
      scroller.scrollTo(tabIDs[index], anchor: placement == .before ? .leading : .trailing)
    }
  }
}
