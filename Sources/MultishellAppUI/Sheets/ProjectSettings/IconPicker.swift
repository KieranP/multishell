import MultishellAppCore
import MultishellCore
import SwiftUI

/// The curated symbols as a palette: a grid read by shape carries hundreds
/// where a popup menu held sixty. Keyboard-driven throughout.
struct IconPicker: View {
  let kind: ProjectIcon.Kind
  let tint: Color
  let choose: (String?) -> Void

  @State private var isPresented = false
  @State private var highlighted: String?
  @FocusState private var gridFocused: Bool

  private static let columns = 10
  private static let cellSize: Double = 26

  var body: some View {
    Button {
      highlighted = chosen
      isPresented = true
    } label: {
      field
    }
    .popover(isPresented: $isPresented, arrowEdge: .bottom) { palette }
  }

  private var field: some View {
    HStack(spacing: 6) {
      Image(systemName: kind.symbolName).foregroundStyle(tint)
      switch kind {
      case .folder: Text(t("icon-picker.folder"))
      case .symbol(let name): Text(name).lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: 4)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .frame(width: 190)
  }

  private var palette: some View {
    let groups = ProjectIcon.symbolGroups
    return ScrollViewReader { proxy in
      VStack(spacing: 6) {
        grid(groups, proxy: proxy)
        jumps(groups, proxy: proxy)
      }
      .onAppear {
        highlighted = chosen
        // A frame later: the grid is lazy, so neither the cell nor the
        // ring's own row exists during the first layout pass.
        Task {
          gridFocused = true
          proxy.scrollTo(chosen, anchor: .center)
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
            ForEach(group.glyphs, id: \.self) { cell($0) }
          } header: {
            header(group.name).id(Self.headerID(group.name))
          }
        }
      }
      .padding(.horizontal, 8)
      // The search field used to carry the top of the popover; the grid does
      // now, or the first row of symbols sits against its edge.
      .padding(.vertical, 8)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($gridFocused)
    .onKeyPress(.leftArrow) { walk(.left, through: groups, proxy: proxy) }
    .onKeyPress(.rightArrow) { walk(.right, through: groups, proxy: proxy) }
    .onKeyPress(.upArrow) { walk(.up, through: groups, proxy: proxy) }
    .onKeyPress(.downArrow) { walk(.down, through: groups, proxy: proxy) }
    .onKeyPress(.return) { pickHighlighted() }
  }

  /// One button per group, its first symbol standing for it, as the emoji
  /// picker's categories do.
  private func jumps(_ groups: [ProjectIcon.Group], proxy: ScrollViewProxy) -> some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 0) {
        ForEach(groups, id: \.name) { group in
          Button {
            proxy.scrollTo(Self.headerID(group.name), anchor: .top)
          } label: {
            Image(systemName: group.glyphs.first ?? "square")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              // Shared width, not a fixed one: a fifteenth group would
              // otherwise run off the edge of the popover unnoticed.
              .frame(maxWidth: .infinity, minHeight: 20)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .help(group.name)
          .accessibilityLabel(group.name)
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 4)
      .padding(.bottom, 6)
    }
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

  private func cell(_ name: String) -> some View {
    let selected = chosen == name
    return Button {
      pick(name)
    } label: {
      Image(systemName: name)
        .font(.system(size: 14))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(width: Self.cellSize, height: Self.cellSize)
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
          if highlighted == name, gridFocused {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 2)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(name)
    .accessibilityLabel(name)
  }

  /// Return picks what the ring is on, and is left alone when there is no
  /// ring, rather than swallowed.
  private func pickHighlighted() -> KeyPress.Result {
    guard let highlighted else { return .ignored }
    pick(highlighted)
    return .handled
  }

  private func pick(_ name: String) {
    // The folder cell is the way back to no glyph at all, so it stores
    // nothing rather than storing its name.
    choose(name == ProjectIcon.folderSymbol ? nil : name)
    isPresented = false
  }

  private func walk(
    _ step: IconGridWalk.Step, through groups: [ProjectIcon.Group], proxy: ScrollViewProxy
  ) -> KeyPress.Result {
    let rows = IconGridWalk.rows(of: groups, columns: Self.columns)
    guard let to = IconGridWalk.destination(from: highlighted, step: step, in: rows) else {
      return .ignored
    }
    return move(to: to, proxy: proxy)
  }

  private func move(to name: String, proxy: ScrollViewProxy) -> KeyPress.Result {
    highlighted = name
    proxy.scrollTo(name, anchor: .center)
    return .handled
  }

  private var chosen: String { kind.symbolName }
}
