import MultishellAppCore
import MultishellCore
import SwiftUI

/// The space the content's leading edge is measured in to give the scroll
/// offset. Outside the type, not a `static let` on it: static stored
/// properties are not allowed in a generic type, as `WeightedSplit` says of
/// its own constants.
private let scrollSpace = "tabStrip"

/// The tabs of a strip whose tabs have shrunk as far as they go and still do
/// not fit: a scroller, with an arrow at each end that has tabs past it.
///
/// It knows how many tabs there are and which one is showing, never what a
/// tab is: `TabBar` decides that and hands them over. What it owns is the
/// scroll position, which nothing outside needs.
struct ScrollingTabStrip<Tabs: View>: View {
  let model: AppModel
  let theme: Theme
  /// How wide each tab is drawn, and the floor it stopped at; see
  /// `TabStripLayout`.
  let layout: TabStripLayout
  /// The room the strip has, the New Tab button's width already taken off.
  let available: Double
  /// In strip order, for the arrows to scroll by one and for the count.
  let tabIDs: [TerminalTab.ID]
  /// The tab showing, brought into view as it changes.
  let activeID: TerminalTab.ID?
  @ViewBuilder let tabs: () -> Tabs

  /// How far it has been scrolled, which decides which end carries an arrow
  /// and where that arrow jumps to; see `TabStripLayout.Edges` and
  /// `stepTarget`.
  @State private var scrollOffset = 0.0

  /// No gutters at all in a strip without the room for them and a tab
  /// besides, which a window dragged narrow enough over enough columns
  /// reaches: two arrows and nothing to scroll would be drawn straight over
  /// the column beside it. The tabs still scroll, by trackpad.
  private var gutter: Double {
    available >= 2 * model.metrics.tabArrowWidth + model.metrics.tabMinWidth
      ? model.metrics.tabArrowWidth : 0
  }

  /// Both gutters keep their room whether an arrow is drawn or not, so the
  /// tabs do not shift under the pointer as one end runs out — and so this,
  /// which decides which arrows show, cannot change what it is measured from.
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
            .background { offsetReader }
        }
        .coordinateSpace(.named(scrollSpace))
        arrow(.after, shown: edges.trailing, scroller: scroller)
      }
      // Unwrapped, both of them: `scrollTo` takes anything hashable, and a
      // `TerminalTab.ID?` compiles but matches nothing, `ForEach` having
      // identified each tab by the id itself.
      .onAppear {
        if let activeID { scroller.scrollTo(activeID, anchor: .center) }
      }
      .onChange(of: activeID) { _, id in
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.16)) { scroller.scrollTo(id, anchor: .center) }
      }
    }
  }

  /// One end's arrow: drawn only where there are tabs past it, and a button
  /// rather than a hint, since something that says there is more should be
  /// the way to get to it. A click brings the first tab past that end into
  /// view; see `TabStripLayout.stepTarget`.
  ///
  /// An arrow drawn over the tabs would either take the click meant for the
  /// tab under it or sit there looking like a button and doing nothing, so
  /// it has a gutter of its own outside the scroller.
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

  /// How far the tabs have been scrolled: the content's own leading edge,
  /// measured in the scroller's space, is the offset with its sign turned
  /// round.
  ///
  /// Reported through `onChange` rather than a `PreferenceKey`, whose
  /// `onPreferenceChange` closure is `@Sendable` in this SDK: a view holding
  /// a `@MainActor` model cannot write state from one. These actions run in
  /// the view's own context, after the update rather than during it.
  private var offsetReader: some View {
    GeometryReader { content in
      let offset = -Double(content.frame(in: .named(scrollSpace)).minX)
      Color.clear
        .onAppear { scrollOffset = offset }
        .onChange(of: offset) { _, moved in scrollOffset = moved }
    }
  }
}
