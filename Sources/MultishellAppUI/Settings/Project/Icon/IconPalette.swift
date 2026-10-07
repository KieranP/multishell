import MultishellAppCore
import MultishellCore
import SwiftUI

/// The curated symbols as a grid read by shape, which carries hundreds where a
/// popup menu held sixty. Keyboard-driven throughout; `IconPicker` pops it up.
struct IconPalette: View {
  let kind: ProjectIcon.Kind
  let pick: (String) -> Void

  @State private var highlighted: String?
  @FocusState private var isGridFocused: Bool

  private static let columns = 10
  private static let cellSize: Double = 26

  var body: some View {
    let groups = ProjectIcon.symbolGroups
    return ScrollViewReader { proxy in
      VStack(spacing: 6) {
        grid(groups, proxy: proxy)
        IconPaletteGroupBar(groups: groups) { proxy.scrollTo(Self.headerID($0), anchor: .top) }
      }
      .onAppear {
        highlighted = currentSymbol
        // A frame later: the grid is lazy, so neither the cell nor the
        // ring's own row exists during the first layout pass.
        Task {
          isGridFocused = true
          proxy.scrollTo(currentSymbol, anchor: .center)
        }
      }
    }
    .frame(width: Double(Self.columns) * (Self.cellSize + 2) + 22, height: 360)
  }

  private func grid(_ groups: [ProjectIcon.Group], proxy: ScrollViewProxy) -> some View {
    ScrollView {
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.fixed(Self.cellSize), spacing: 2), count: Self.columns),
        spacing: 2,
        pinnedViews: [.sectionHeaders]
      ) {
        ForEach(groups, id: \.name) { group in
          Section {
            ForEach(group.symbols, id: \.self) { symbol in
              IconPaletteCell(
                symbol: symbol, isCurrent: symbol == currentSymbol,
                isHighlighted: highlighted == symbol && isGridFocused, size: Self.cellSize,
                pick: { pick(symbol) })
            }
          } header: {
            header(group.name).id(Self.headerID(group.name))
          }
        }
      }
      .padding(.horizontal, 8)
      // The grid carries the popover's top inset, or its first row sits
      // against the edge.
      .padding(.vertical, 8)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($isGridFocused)
    .onKeyPress(.leftArrow) { walk(.left, through: groups, proxy: proxy) }
    .onKeyPress(.rightArrow) { walk(.right, through: groups, proxy: proxy) }
    .onKeyPress(.upArrow) { walk(.up, through: groups, proxy: proxy) }
    .onKeyPress(.downArrow) { walk(.down, through: groups, proxy: proxy) }
    .onKeyPress(.return) { pickHighlighted() }
  }

  private static func headerID(_ group: String) -> String { "header." + group }

  private func header(_ name: String) -> some View {
    Text(name)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 3)
      .background(.regularMaterial)
  }

  /// Return picks what the ring is on, and is left alone when there is no
  /// ring, rather than swallowed.
  private func pickHighlighted() -> KeyPress.Result {
    guard let highlighted else { return .ignored }
    pick(highlighted)
    return .handled
  }

  private func walk(
    _ step: IconGridWalk.Step, through groups: [ProjectIcon.Group], proxy: ScrollViewProxy
  ) -> KeyPress.Result {
    let rows = IconGridWalk.rows(of: groups, columns: Self.columns)
    guard let destination = IconGridWalk.destination(from: highlighted, step: step, in: rows) else {
      return .ignored
    }
    return move(to: destination, proxy: proxy)
  }

  private func move(to symbol: String, proxy: ScrollViewProxy) -> KeyPress.Result {
    highlighted = symbol
    proxy.scrollTo(symbol, anchor: .center)
    return .handled
  }

  private var currentSymbol: String { kind.symbolName }
}
