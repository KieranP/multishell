import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The sections under their titles, scrolled to keep the selected row in sight.
struct QuickSwitcherList: View {
  private static let listTop = "listTop"

  let results: QuickSwitcherResults
  let theme: Theme
  let metrics: UIMetrics
  let choose: (QuickSwitcherTarget) -> Void
  let point: (QuickSwitcherTarget) -> Void
  let forgetLostSelection: () -> Void

  /// Made once on appearing; an initial value here is built on every render.
  @State private var pointer: QuickSwitcherPointer?

  private var palette: AreaPalette { theme.quickSwitcher }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: UIMetrics.sidebarRowSpacing) {
          ForEach(results.sections) { section in
            Text(section.kind.title)
              .font(metrics.font(size: metrics.caption, weight: .semibold))
              .foregroundStyle(palette.textTertiary)
              .padding(.horizontal, UIMetrics.quickSwitcherRowInset)
              .frame(height: UIMetrics.sectionHeaderHeight, alignment: .bottom)
              .accessibilityAddTraits(.isHeader)
              .id(section.id)
            ForEach(section.items) { item in
              QuickSwitcherRow(
                item: item,
                isSelected: item.target == results.selection,
                theme: theme,
                metrics: metrics,
                choose: { choose(item.target) },
                point: { pointIfMoved(at: item.target) },
              )
              .id(item.target)
            }
          }
        }
        .padding(UIMetrics.quickSwitcherListPadding)
        .id(Self.listTop)
      }
      .scrollIndicators(.automatic)
      .onAppear { pointer = QuickSwitcherPointer(location: NSEvent.mouseLocation) }
      .onChange(of: results) { previous, current in
        scroll(to: current.scrollTarget(after: previous), with: proxy)
        // Rows moved under the pointer; only its moving from here selects.
        pointer?.location = NSEvent.mouseLocation
        if current.isSelectionLost { forgetLostSelection() }
      }
      .onChange(of: results.arrowPresses) {
        if let selection = results.selection { announce(selection) }
      }
    }
  }

  /// One scroll a move: a second would undo the first.
  private func scroll(to target: QuickSwitcherScrollTarget?, with proxy: ScrollViewProxy) {
    switch target {
    case .top: proxy.scrollTo(Self.listTop, anchor: .top)
    case .sectionTitle(let kind): proxy.scrollTo(kind)
    case .row(let row): proxy.scrollTo(row)
    case nil: break
    }
  }

  /// Rows moving under a still pointer leave the selection alone; only the
  /// pointer moving takes it.
  private func pointIfMoved(at target: QuickSwitcherTarget) {
    let location = NSEvent.mouseLocation
    guard let pointer, location != pointer.location else { return }
    pointer.location = location
    point(target)
  }

  /// The keyboard stays in the field, so VoiceOver is told which row the
  /// arrows reached, as it would hear a list it was in.
  private func announce(_ target: QuickSwitcherTarget) {
    let items = results.sections.lazy.flatMap(\.items)
    guard let item = items.first(where: { $0.target == target }) else { return }
    NSAccessibility.post(
      element: NSApp as Any,
      notification: .announcementRequested,
      userInfo: [
        .announcement: AccessibilityText.quickSwitcherRow(item, at: .now),
        .priority: NSAccessibilityPriorityLevel.high.rawValue,
      ],
    )
  }
}
